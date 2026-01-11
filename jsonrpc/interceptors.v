module jsonrpc


// pub interface Interceptor {
// mut:
// 	on_event(name string, data string) !
// 	on_encoded_request(req []u8) !
// 	on_request(req &Request) !
// 	on_response(resp &Response)
// 	on_encoded_response(resp []u8)
// }

pub type EventInterceptor =	fn(name string, data string)

pub interface EncodedRequestInterceptor {
mut:
	on_encoded_request(req []u8) !
}

pub interface RequestInterceptor {
mut:
	on_request(req &Request) !
}

pub interface ResponseInterceptor {
mut:
	on_response(resp &Response)
}

pub interface EncodedResponseInterceptor {
mut:
	on_encoded_response(resp []u8)
}

pub struct Interceptors {
pub mut:
	event []EventInterceptor
	encoded_request []EncodedRequestInterceptor
	request []RequestInterceptor
	response []ResponseInterceptor
	encoded_response []EncodedResponseInterceptor
}

pub fn dispatch_event(ints []EventInterceptor, event_name string, data string) {
	for i in ints {
		i(event_name, data)
	}
}

pub fn (mut s Server) intercept_encoded_request(req []u8) ! {
	for mut interceptor in s.interceptors.encoded_request {
		interceptor.on_encoded_request(req)!
	}
}

pub fn (mut s Server) intercept_request(req &Request) ! {
	for mut interceptor in s.interceptors.request {
		interceptor.on_request(req)!
	}
}

pub fn (mut s Server) intercept_response(resp &Response) {
	for mut interceptor in s.interceptors.response {
		interceptor.on_response(resp)
	}
}

pub fn (mut s Server) intercept_encoded_response(resp []u8) {
	for mut interceptor in s.interceptors.encoded_response {
		interceptor.on_encoded_response(resp)
	}
}

pub fn (s &Server) is_interceptor_enabled[T]() bool {
	s.get_interceptor[T]() or { return false }
	return true
}

pub fn (s &Server) get_interceptor[T]() ?&T {
	for inter in s.encreqint {
		if inter is T {
			return inter
		}
	}
	for inter in s.reqint {
		if inter is T {
			return inter
		}
	}
	for inter in s.respint {
		if inter is T {
			return inter
		}
	}
	for inter in s.encrespint {
		if inter is T {
			return inter
		}
	}

	return none
}