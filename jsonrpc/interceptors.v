module jsonrpc


// pub interface Interceptor {
// mut:
// 	on_event(name string, data string) !
// 	on_encoded_request(req []u8) !
// 	on_request(req &Request) !
// 	on_response(resp &Response)
// 	on_encoded_response(resp []u8)
// }

pub interface EventInterceptor {
mut:
	on_event(name string, data string)

}
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

pub fn (mut s Server) dispatch_event(event_name string, data string) {
	for mut i in s.eint {
		i.on_event(event_name, data)
	}
}

pub fn (mut s Server) intercept_encoded_request(req []u8) ! {
	for mut interceptor in s.encreqint {
		interceptor.on_encoded_request(req)!
	}
}

pub fn (mut s Server) intercept_request(req &Request) ! {
	for mut interceptor in s.reqint {
		interceptor.on_request(req)!
	}
}

pub fn (mut s Server) intercept_response(resp &Response) {
	for mut interceptor in s.respint {
		interceptor.on_response(resp)
	}
}

pub fn (mut s Server) intercept_encoded_response(resp []u8) {
	for mut interceptor in s.encrespint {
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