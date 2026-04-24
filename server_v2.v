module jsonrpcv

import io

pub struct ServerConfigV2 {
pub mut:
	stream       io.ReaderWriter
	handler      HandlerV2 @[required]
	interceptors Interceptors
}

// ServerV2 represents a JSONRPC server that sends/receives data
// from a stream io.ReaderWriter.
@[heap]
pub struct ServerV2 {
mut:
	stream       io.ReaderWriter
	handler      HandlerV2 @[required]
	interceptors Interceptors
}

pub fn new_server_v2(cfg ServerConfigV2) ServerV2 {
	return ServerV2{
		stream:       cfg.stream
		handler:      cfg.handler
		interceptors: cfg.interceptors
	}
}

fn parse_request(raw_req []u8) ![]Request {
	req_str := raw_req.bytestr()

	mut req_batch := []Request{}
	match req_str[0].ascii_str() {
		'[' {
			req_batch = decode_batch_request(req_str)!
		}
		'{' {
			req := decode_request(req_str)!
			req_batch.prepend(req)
		}
		else {
			return parse_error
		}
	}
	return req_batch
}

// respond reads bytes from stream, pass them to the `interceptors.encoded_request`,
// tries to decode into `Request` and pass to `interceptors.request`
// and on fail it responds with `parse_error` after that it calls handlers
// (batch requests are handled automatically as well as writing batch response)
// and passes recieved `Response` into `interceptors.response` and the
// last step is to encode `Response`, pass it into `interceptors.encoded_response`
// and write to stream
pub fn (mut s ServerV2) respond() ! {
	mut rx := []u8{len: 4096}
	s.stream.read(mut rx)!

	intercept_encoded_request(s.interceptors.encoded_request, rx) or {
		s.stream.write(Response{ error: response_error(error: parse_error) }.encode().bytes()) or {
			eprintln('error sending response: ${err}')
			return
		}
		return err
	}

	mut req_batch := parse_request(rx) or {
		s.stream.write(Response{ error: response_error(error: parse_error) }.encode().bytes()) or {
			eprintln('error sending response: ${err}')
			return
		}
		return err
	}

	mut resp_batch := []Response{}
	for rq in req_batch {
		req_id := rq.id

		intercept_request(s.interceptors.request, &rq) or {
			s.stream.write(rq.err_resp(response_error(error: err)).encode().bytes()) or {
				eprintln('error sending response: ${err}')
				return
			}
			return err
		}

		resp := s.handler.handle(rq)
		out_resp := Response{
			result: if resp.error.code != 0 { '' } else { resp.result }
			error:  resp.error
			id:     req_id
		}

		intercept_response(s.interceptors.response, resp)
		resp_batch << out_resp
	}

	enc_resp := if resp_batch.len == 1 {
		resp_batch[0].encode().bytes()
	} else {
		resp_batch.encode_batch().bytes()
	}

	intercept_encoded_response(s.interceptors.encoded_response, enc_resp)
	s.stream.write(enc_resp) or {
		eprintln('error sending response: ${err}')
		return
	}
}

// start `ServerV2` loop to operate on `stream` passed into constructor
// it calls `ServerV2.respond()` method in loop
pub fn (mut s ServerV2) start() {
	for {
		s.respond() or {
			if err is io.Eof {
				return
			}
		}
	}
}

// HandlerV2 is the struct called when `Request` is
// decoded and `Response` is required which is written
// back to the server stream.
pub interface HandlerV2 {
	handle(req Request) Response
}

// HandleFn is fn called on `Request` by ServerV2
pub type HandleFn = fn (Request) Response

// RouterV2 is simple map of method names and their `Handler`s
pub struct RouterV2 {
mut:
	methods map[string]HandleFn
}

// handle is called by `ServerV2` to operate on `Request`
// it simply tries to invoke registered methods and if none valid found
// writes `Response` with `method_not_found` error
pub fn (r RouterV2) handle(req Request) Response {
	h := r.methods[req.method] or { return req.err_resp(method_not_found) }
	return h(req)
}

// register `HandleFn` to operate when `method` found in incoming `Request`
pub fn (mut r RouterV2) register(method string, handle_fn HandleFn) bool {
	if method in r.methods {
		return false
	}

	r.methods[method] = handle_fn
	return true
}
