module jsonrpc

pub interface InterceptorData {}

pub interface EventInterceptor {
mut:
	on_event(name string, data InterceptorData) !
}

pub interface RawRequestInterceptor {
mut:
	on_raw_request(req []u8) !
}

pub interface RequestInterceptor {
mut:
	on_request(req &Request) !
}

pub interface EncodedResponseInterceptor {
mut:
	on_encoded_response(resp []u8)
}

struct InterceptorWriter {
mut:
	interceptors []EncodedResponseInterceptor
}

fn (mut wr InterceptorWriter) write(buf []u8) !int {
	for mut interceptor in wr.interceptors {
		interceptor.on_encoded_response(buf)
	}
	return buf.len
}

pub fn (mut s Server) dispatch_event(event_name string, data InterceptorData) ! {
	for mut i in s.e_inters {
		i.on_event(event_name, data)!
	}
}

pub fn (mut s Server) intercept_raw_request(req []u8) ! {
	for mut interceptor in s.raw_req_inters {
		interceptor.on_raw_request(req)!
	}
}

pub fn (mut s Server) intercept_request(req &Request) ! {
	for mut interceptor in s.req_inters {
		interceptor.on_request(req)!
	}
}

pub fn (mut s Server) intercept_encoded_response(resp []u8) {
	for mut interceptor in s.enc_resp_inters {
		interceptor.on_encoded_response(resp)
	}
}

pub fn (s &Server) is_interceptor_enabled[T]() bool {
	s.get_interceptor[T]() or { return false }
	return true
}

pub fn (s &Server) get_interceptor[T]() ?&T {
	for inter in s.e_inters {
		if inter is T {
			return inter
		}
	}
	for inter in s.raw_req_inters {
		if inter is T {
			return inter
		}
	}
	for inter in s.req_inters {
		if inter is T {
			return inter
		}
	}
	for inter in s.enc_resp_inters {
		if inter is T {
			return inter
		}
	}
	return none
}