module jsonrpc

pub fn (mut s Server) intercept_raw_request(req []u8) ! {
	for mut interceptor in s.interceptors {
		interceptor.on_raw_request(req)!
	}
}

pub fn (mut s Server) intercept_request(req &Request) ! {
	for mut interceptor in s.interceptors {
		interceptor.on_request(req)!
	}
}

pub fn (mut s Server) intercept_encoded_response(resp []u8) {
	for mut interceptor in s.interceptors {
		interceptor.on_encoded_response(resp)
	}
}

pub fn (s &Server) is_interceptor_enabled[T]() bool {
	s.get_interceptor[T]() or { return false }
	return true
}

pub fn (s &Server) get_interceptor[T]() ?&T {
	for inter in s.interceptors {
		if inter is T {
			return inter
		}
	}
	return none
}


pub interface InterceptorData {}

pub fn (mut s Server) dispatch_event(event_name string, data InterceptorData) ! {
	for mut i in s.interceptors {
		i.on_event(event_name, data)!
	}
}

pub interface Interceptor {
mut:
	on_event(name string, data InterceptorData) !
	on_raw_request(req []u8) !
	on_request(req &Request) !
	on_encoded_response(resp []u8)
}

struct InterceptorWriter {
mut:
	interceptors []Interceptor
}

fn (mut wr InterceptorWriter) write(buf []u8) !int {
	for mut interceptor in wr.interceptors {
		interceptor.on_encoded_response(buf)
	}
	return buf.len
}

// pub struct PassiveHandler {}
// fn (mut h PassiveHandler) handle_jsonrpc(req &Request, mut rw ResponseWriter) {}