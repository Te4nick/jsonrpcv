module jsonrpcv

import strings

struct StringRW {
mut:
	buf strings.Builder = strings.new_builder(4096)
}

fn (mut s StringRW) read(mut buf []u8) !int {
	len := s.buf.len
	buf = s.buf.str().bytes()
	s.buf = strings.new_builder(4096)
	return len
}

fn (mut s StringRW) write(buf []u8) !int {
	return s.buf.write(buf)
}

struct KVItem {
	key   string
	value string
}

struct HandlerV2Test {}

fn (h HandlerV2Test) handle(req Request) Response {
	p := req.decode_params[KVItem]() or { return req.err_resp(invalid_params) }

	return req.ok_resp(p)
}

fn handle_test(req Request) Response {
	p := req.decode_params[KVItem]() or { return req.err_resp(invalid_params) }

	return req.ok_resp(p)
}

fn test_server_request_response() {
	mut stream := StringRW{}
	mut srv := new_server_v2(ServerConfigV2{
		stream:  stream
		handler: HandlerV2Test{}
	})

	id := 'req'
	method := 'kv.item'
	params := KVItem{
		key:   'foo'
		value: 'bar'
	}
	stream.write(new_request(method, params, id).encode().bytes())!

	srv.respond()!

	mut enc_resp := []u8{len: 4096}
	stream.read(mut enc_resp)!
	resp := decode_response(enc_resp.bytestr())!

	assert resp.jsonrpc == version
	assert resp.decode_result[KVItem]()! == params
	assert resp.error == ResponseError{}
	assert resp.id == id
}

fn test_server_router_request_response() {
	mut r := RouterV2{}
	method := 'kv.item'
	r.register(method, handle_test)
	mut stream := StringRW{}
	mut srv := new_server_v2(ServerConfigV2{
		stream:  stream
		handler: r
	})

	id := 'req'
	params := KVItem{
		key:   'foo'
		value: 'bar'
	}
	stream.write(new_request(method, params, id).encode().bytes())!

	srv.respond()!

	mut enc_resp := []u8{len: 4096}
	stream.read(mut enc_resp)!
	mut resp := decode_response(enc_resp.bytestr())!

	assert resp.jsonrpc == version
	assert resp.decode_result[KVItem]()! == params
	assert resp.error == ResponseError{}
	assert resp.id == id

	stream.write(new_request('unknown', params, id).encode().bytes())!

	srv.respond()!

	enc_resp = []u8{len: 4096}
	stream.read(mut enc_resp)!
	resp = decode_response(enc_resp.bytestr())!

	assert resp.jsonrpc == version
	assert resp.decode_result[Empty]()! == empty
	assert resp.error == method_not_found
	assert resp.id == id
}
