module jsonrpc

import time

pub struct LoggingInterceptor {}

pub fn (mut l LoggingInterceptor) on_raw_request(req []u8) ! {
	// NOTE: server.v doesn't call intercept_raw_request() by default
	println('[RAW] ${time.now()}')
	println(req.bytestr())
}

pub fn (mut l LoggingInterceptor) on_request(req &Request) ! {
	println('[REQ] ${time.now()} method=${req.method} id=${req.id} params=${req.params}')
}

pub fn (mut l LoggingInterceptor) on_encoded_response(resp []u8) {
	println('[RES] ${time.now()}')
	println(resp.bytestr())
}
