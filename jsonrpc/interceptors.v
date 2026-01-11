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
pub type EncodedRequestInterceptor = fn(req []u8) !
pub type RequestInterceptor = fn(req &Request) !
pub type ResponseInterceptor = fn(resp &Response)
pub type EncodedResponseInterceptor = fn(resp []u8)


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

pub fn intercept_encoded_request(ints []EncodedRequestInterceptor, req []u8) ! {
	for i in ints {
		i(req)!
	}
}

pub fn intercept_request(ints []RequestInterceptor, req &Request) ! {
	for i in ints {
		i(req)!
	}
}

pub fn intercept_response(ints []ResponseInterceptor, resp &Response) {
	for i in ints {
		i(resp)
	}
}

pub fn intercept_encoded_response(ints []EncodedResponseInterceptor, resp []u8) {
	for i in ints {
		i(resp)
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