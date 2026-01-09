module jsonrpc

import json
import strings
import io

pub struct ServerConfig {
pub mut:
	write_to     io.Writer
	read_from    io.Reader
	handler      Handler
	e_inters []EventInterceptor
	raw_req_inters []RawRequestInterceptor
	req_inters []RequestInterceptor
	enc_resp_inters []EncodedResponseInterceptor
}

// Server represents a JSONRPC server that sends/receives data
// from a stream (an io.ReaderWriter) and uses Content-Length framing. :contentReference[oaicite:6]{index=6}
@[heap]
pub struct Server {
mut:
	write_to     io.Writer
	read_from    io.Reader
	handler      Handler
	e_inters []EventInterceptor
	raw_req_inters []RawRequestInterceptor
	req_inters []RequestInterceptor
	enc_resp_inters []EncodedResponseInterceptor
}

pub fn new_server(cfg ServerConfig) Server {
	return Server{
		write_to: cfg.write_to
		read_from: cfg.read_from
		handler: cfg.handler
		e_inters: cfg.e_inters
		raw_req_inters: cfg.raw_req_inters
		req_inters: cfg.req_inters
		enc_resp_inters: cfg.enc_resp_inters
	}

}

// process_raw_request decodes raw request into JSONRPC Request by reading after \r\n\r\n. :contentReference[oaicite:7]{index=7}
fn (s Server) process_raw_request(raw_request string) !Request {
	json_payload := raw_request.all_after('\r\n\r\n')
	return json.decode(Request, json_payload) or { return err }
}

fn (s Server) process_raw_batch_request(raw_request string) ![]Request {
	json_payload := raw_request.all_after('\r\n\r\n')
	return json.decode([]Request, json_payload) or { return err }
}

pub fn (mut s Server) respond() ! {
	mut rw := s.writer()
	mut rx := []u8{len: 4096}
	bytes_read := s.read_from.read(mut rx) or {
		if err is io.Eof {
			return
		}
		return err
	}

	if bytes_read == 0 {
		return
	}

	s.intercept_raw_request(rx) or {
		rw.write_error(response_error(error: err))
		return err
	}

	req_str := rx.bytestr()

	mut req_batch := []Request{}
	match req_str[0].ascii_str() {
		'[' {
			req_batch = s.process_raw_batch_request(req_str) or {
				rw.write_error(response_error(error: parse_error))
				return err
			}
			rw.start_batch()
		}
		'{' {
			req := s.process_raw_request(req_str) or {
				rw.write_error(response_error(error: parse_error))
				return err
			}
			req_batch.prepend(req)
		}
		else {
			rw.write_error(response_error(error: parse_error))
			return parse_error
		}
	}

	for rq in req_batch {
		rw.req_id = rq.id

		s.intercept_request(&rq) or {
			rw.write_error(response_error(error: err))
			return err
		}

		s.handler.handle_jsonrpc(&rq, mut rw)
	}

	if req_batch.len > 1 {
		rw.close_batch()
	}
}

@[params]
pub struct NewWriterConfig {
	own_buffer bool
}

pub fn (s &Server) writer(cfg NewWriterConfig) &ResponseWriter {
	return &ResponseWriter{
		writer: io.MultiWriter{
			writers: [
				InterceptorWriter{
					interceptors: s.enc_resp_inters
				},
				s.write_to
			]
		}
		sb:     strings.new_builder(4096)
	}
}

pub fn (mut s Server) start() {
	for {
		s.respond() or {
			if err is io.Eof {
				return
			}
		}
	}
}

pub interface Handler {
mut:
	handle_jsonrpc(req &Request, mut wr ResponseWriter)
}

pub struct ResponseWriter {
mut:
	sb       strings.Builder
	is_batch bool
pub mut:
	req_id string = 'null'
	writer io.Writer
}

fn (mut rw ResponseWriter) start_batch() {
	rw.is_batch = true
	rw.sb.write_string('[')
}

fn (mut rw ResponseWriter) close_batch() {
	rw.sb.go_back(2)
	rw.sb.write_string(']')
	rw.close()
}

fn (mut rw ResponseWriter) close() {
	rw.writer.write(rw.sb) or {}
	rw.sb.go_back_to(0)
}

pub fn (mut rw ResponseWriter) write[T](payload T) {
	final_resp := Response[T]{
		id:     rw.req_id
		result: payload
	}
	encode_response[T](final_resp, mut rw.sb)

	accumulated := rw.sb.str()
	rw.sb = strings.new_builder(4096)
	rw.sb.write_string(accumulated)

	if rw.is_batch == true {
		rw.sb.write_string(', ')
		return
	}
	rw.close()
}

pub fn (mut rw ResponseWriter) write_empty() {
	rw.write[Null](null)
}

pub fn (mut rw ResponseWriter) write_notify[T](method string, params T) {
	notif := NotificationMessage[T]{
		method: method
		params: params
	}
	encode_notification[T](notif, mut rw.sb)
	if rw.is_batch {
		rw.sb.write_string(', ')
		return
	}
	rw.close()
}

pub fn (mut rw ResponseWriter) write_error(err IError) {
	mut res_err := err
	if err !is ResponseError {
		if err.code() !in error_codes {
			res_err = response_error(error: unknown_error)
		} else {
			res_err = response_error(error: err)
		}
	}

	final_resp := Response[string]{
		id:    rw.req_id
		error: res_err as ResponseError
	}
	encode_response[string](final_resp, mut rw.sb)
	if rw.is_batch {
		rw.sb.write_string(', ')
		return
	}
	rw.close()
}