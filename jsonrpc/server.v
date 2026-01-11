module jsonrpc

import json
import strings
import io

pub struct ServerConfig {
pub mut:
	stream    io.ReaderWriter
	handler      Handler
	interceptors Interceptors
}

// Server represents a JSONRPC server that sends/receives data
// from a stream (an io.ReaderWriter) and uses Content-Length framing. :contentReference[oaicite:6]{index=6}
@[heap]
pub struct Server {
mut:
	stream    io.ReaderWriter
	handler      Handler
	interceptors Interceptors
}

pub fn new_server(cfg ServerConfig) Server {
	return Server{
		stream: cfg.stream
		handler: cfg.handler
		interceptors: cfg.interceptors
	}

}

pub fn (mut s Server) respond() ! {
	mut rw := s.writer()
	mut rx := []u8{len: 4096}
	bytes_read := s.stream.read(mut rx) or {
		if err is io.Eof {
			return
		}
		return err
	}

	if bytes_read == 0 {
		return
	}

	intercept_encoded_request(s.interceptors.encoded_request, rx) or {
		rw.write_error(response_error(error: err))
		return err
	}

	req_str := rx.bytestr()

	mut req_batch := []Request{}
	match req_str[0].ascii_str() {
		'[' {
			req_batch = decode_batch_request(req_str) or {
				rw.write_error(response_error(error: parse_error))
				return err
			}
			rw.start_batch()
		}
		'{' {
			req := decode_request(req_str) or {
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

		intercept_request(s.interceptors.request, &rq) or {
			rw.write_error(response_error(error: err))
			return err
		}

		s.handler.handle_jsonrpc(&rq, mut rw)
	}

	if req_batch.len > 1 {
		rw.close_batch()
	}
}

fn (s &Server) writer() &ResponseWriter {
	return &ResponseWriter{
		writer: s.stream
		sb:     strings.new_builder(4096)
		server: s
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
	server &Server
pub mut:
	req_id string
	writer io.ReaderWriter
}

fn (mut rw ResponseWriter) start_batch() {
	rw.is_batch = true
	rw.sb.write_string('[')
}

fn (mut rw ResponseWriter) close_batch() {
	rw.is_batch = false
	rw.sb.go_back(2)
	rw.sb.write_string(']')
	rw.close()
}

fn (mut rw ResponseWriter) close() {
	intercept_encoded_response(rw.server.interceptors.encoded_response, rw.sb)
	rw.writer.write(rw.sb) or {}
	rw.sb.go_back_to(0)
}

pub fn (mut rw ResponseWriter) write[T](payload T) {
	final_resp := Response{
		id:     rw.req_id
		result: json.encode(payload)
	}
	
	intercept_response(rw.server.interceptors.response, final_resp)

	if rw.req_id.len == 0 {
		return
	}

	rw.sb.write_string(final_resp.encode())

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
	notif := new_notification(method, params)
	rw.sb.write_string(notif.encode())
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

	final_resp := Response{
		id:    rw.req_id
		error: res_err as ResponseError
	}

	intercept_response(rw.server.interceptors.response, final_resp)

	rw.sb.write_string(final_resp.encode())
	if rw.is_batch {
		rw.sb.write_string(', ')
		return
	}
	rw.close()
}