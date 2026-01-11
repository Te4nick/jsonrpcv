module jsonrpc

import log

@[heap]
pub struct LoggingInterceptor {
pub mut:
	log log.Log
}

pub fn (mut l LoggingInterceptor) on_event(name string, data string) {
	msg := '[EVENT] name=${name} data=${data}'
	l.log.send_output(msg, l.log.get_level())
}

pub fn (mut l LoggingInterceptor) on_encoded_request(req []u8) ! {
	msg := '[RAW REQ] ${req.bytestr()}'
	l.log.send_output(msg, l.log.get_level())
}

pub fn (mut l LoggingInterceptor) on_request(req &Request) ! {
	msg := '[REQ] method=${req.method} params=${req.params} id=${req.id}'
	l.log.send_output(msg, l.log.get_level())
}

pub fn (mut l LoggingInterceptor) on_response(resp &Response) {
	mut msg := '[RESP] result=${resp.result} '
	if resp.error.code != 0 {
		msg = msg + 'error=${resp.error}'
	} else {
		msg = msg + 'error=none'
	}
	msg = msg + ' id=${resp.id}'
	
	l.log.send_output(msg, l.log.get_level())
}

pub fn (mut l LoggingInterceptor) on_encoded_response(resp []u8) {
	msg := '[RAW RESP] ${resp.bytestr()}'
	l.log.send_output(msg, l.log.get_level())
}
