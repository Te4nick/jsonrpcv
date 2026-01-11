module jsonrpc

import json

pub const version = '2.0'

// ---- error helpers ----

pub struct ResponseError {
pub mut:
	code    int
	message string
	data    string
}

pub fn (err ResponseError) code() int { return err.code }
pub fn (err ResponseError) msg() string { return err.message }
pub fn (e ResponseError) err() IError { return IError(e) }

// ResponseErrorGeneratorParams & response_error are used by server.v :contentReference[oaicite:2]{index=2}
@[params]
pub struct ResponseErrorGeneratorParams {
	error IError @[required]
	data  string
}

@[inline]
pub fn response_error(params ResponseErrorGeneratorParams) ResponseError {
	return ResponseError{
		code: params.error.code()
		message: params.error.msg()
		data: params.data
	}
}

pub fn error_with_code(message string, code int) ResponseError {
	return ResponseError{ code: code, message: message, data: '' }
}

// JSON-RPC standard-ish errors :contentReference[oaicite:3]{index=3}

pub const parse_error          = error_with_code('Invalid JSON.', -32700)
pub const invalid_request      = error_with_code('Invalid request.', -32600)
pub const method_not_found     = error_with_code('Method not found.', -32601)
pub const invalid_params       = error_with_code('Invalid params', -32602)
pub const internal_error       = error_with_code('Internal error.', -32693)
pub const server_error_start     = error_with_code('Error occurred when starting server.', -32099)
pub const server_not_initialized = error_with_code('Server not initialized.', -32002)
pub const unknown_error          = error_with_code('Unknown error.', -32001)
pub const server_error_end       = error_with_code('Error occurred when stopping the server.', -32000)
pub const error_codes = [
		parse_error.code(), invalid_request.code(), method_not_found.code(), invalid_params.code(),
		internal_error.code(), server_error_start.code(), server_not_initialized.code(),
		server_error_end.code(), unknown_error.code(),
	]


// Null represents the null value in JSON.
pub struct Null {}
pub const null = Null{}

// ---- request/response ----

// Request uses raw JSON strings for id and params in the old VLS code. :contentReference[oaicite:4]{index=4}
pub struct Request {
pub:
	jsonrpc string = jsonrpc.version
	method  string
	params  string @[raw] // raw JSON object/array/null
	id      string @[omitempty; raw] // raw JSON (e.g. 1 or "abc") if empty => notification (no id field)
}

pub fn new_request[T] (method string, params T, id string) Request {
	return Request{
		method: method
		params: $if params is string { params } $else { json.encode(params) }
		id: id
	}
}

pub fn (req Request) encode() string {
	// If id is empty => notification (no id field)
	id_payload := if req.id.len != 0 { ',"id":"${req.id}",' } else { ',' }
	return '{"jsonrpc":"${jsonrpc.version}"${id_payload}"method":"${req.method}","params":${req.params}}'
}

pub fn (req Request) decode_params[T]() !T {
	return json.decode(T, req.params) or { return err }
}

// decode_request decodes raw request into JSONRPC Request by reading after \r\n\r\n. :contentReference[oaicite:7]{index=7}
pub fn decode_request(raw string) !Request {
	json_payload := raw.all_after('\r\n\r\n')
	return json.decode(Request, json_payload) or { return err }
}

pub fn decode_batch_request(raw string) ![]Request {
	json_payload := raw.all_after('\r\n\r\n')
	return json.decode([]Request, json_payload) or { return err }
}

pub struct Response {
pub:
	jsonrpc string = jsonrpc.version
	result  string @[raw]
	error   ResponseError
	id      string
}

pub fn new_response[T] (result T, error ResponseError, id string) Request {
	res := if error.code != 0 { 
		"" 
	} else {$if result is string { 
		result 
	} $else { 
		json.encode(result) 
	}}
	
	return Request{
		result: res
		error: error
		id: id
	}
}

pub fn (resp Response) encode() string {
	mut s := '{"jsonrpc":"${jsonrpc.version}","id":'
	if resp.id.len == 0 {
		s = s + 'null'
	} else {
		s = s + resp.id
	}
	if resp.error.code != 0 {
		s = s + ',"error":' + json.encode(resp.error)
	} else {
		s = s + ',"result":' + resp.result
	}
	return s + '}'
}

pub fn (resp Response) decode_result[T]() !T {
	return json.decode(T, resp.result) or { return err }
}

pub fn decode_response(raw string) !Response {
	json_payload := raw.all_after('\r\n\r\n')
	return json.decode(Response, json_payload) or { return err }
}

pub fn decode_batch_response(raw string) ![]Response {
	json_payload := raw.all_after('\r\n\r\n')
	return json.decode([]Response, json_payload) or { return err }
}

// Notification is Request without id. :contentReference[oaicite:5]{index=5}
pub struct Notification {
pub:
	jsonrpc string = jsonrpc.version
	method  string
	params  string @[raw]
}

pub fn new_notification[T] (method string, params T) Notification {
	return Notification{
		method: method
		params: $if params is string { params } $else { json.encode(params) }
	}
}

pub fn (notif Notification) to_request() Request {
	return Request{
		method: notif.method
		params: notif.params
	}
}

pub fn (notif Notification) encode() string {
	mut s := '{"jsonrpc":"${jsonrpc.version}","method":"${notif.method}","params":'
	if notif.params.len == 0 {
		s = s + 'null'
	} else {
		s = s + notif.params
	}
	
	return s + '}'
}
