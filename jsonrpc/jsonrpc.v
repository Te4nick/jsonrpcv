module jsonrpc

import json
import strings
import io

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
pub mut:
	jsonrpc string = jsonrpc.version
	id      string @[raw] // raw JSON (e.g. 1 or "abc")
	method  string
	params  string @[raw] // raw JSON object/array/null
}

pub fn (req Request) json() string {
	// If id is empty => notification (no id field)
	id_payload := if req.id.len != 0 { ',"id":$req.id,' } else { ',' }
	return '{"jsonrpc":"$jsonrpc.version"$id_payload"method":"$req.method","params":$req.params}'
}

pub fn (req Request) decode_params[T]() !T {
	return json.decode(T, req.params) or { return err }
}

pub struct Response[T] {
pub:
	jsonrpc string = jsonrpc.version
	id      string
	result  T
	error   ResponseError
}

pub fn (resp Response[T]) json() string {
	mut resp_wr := strings.new_builder(100)
	defer { unsafe { resp_wr.free() } }
	encode_response[T](resp, mut resp_wr)
	return resp_wr.str()
}

const null_in_u8 = 'null'.bytes()
const error_field_in_u8 = ',"error":'.bytes()
const result_field_in_u8 = ',"result":'.bytes()

fn encode_response[T](resp Response[T], mut writer io.Writer) {
	writer.write('{"jsonrpc":"$jsonrpc.version","id":'.bytes()) or {}
	if resp.id.len == 0 {
		writer.write(jsonrpc.null_in_u8) or {}
	} else {
		writer.write(resp.id.bytes()) or {}
	}
	if resp.error.code != 0 {
		err_json := json.encode(resp.error)
		writer.write(jsonrpc.error_field_in_u8) or {}
		writer.write(err_json.bytes()) or {}
	} else {
		writer.write(jsonrpc.result_field_in_u8) or {}
		$if T is Null {
			writer.write(jsonrpc.null_in_u8) or {}
		} $else {
			res_json := json.encode(resp.result)
			writer.write(res_json.bytes()) or {}
		}
	}
	writer.write([u8(`}`)]) or {}
}

// NotificationMessage is Request without id. :contentReference[oaicite:5]{index=5}
pub struct NotificationMessage[T] {
pub:
	jsonrpc string = jsonrpc.version
	method  string
	params  T
}

pub fn (notif NotificationMessage[T]) json() string {
	mut notif_wr := strings.new_builder(100)
	defer { unsafe { notif_wr.free() } }
	encode_notification[T](notif, mut notif_wr)
	return notif_wr.str()
}

fn encode_notification[T](notif NotificationMessage[T], mut writer io.Writer) {
	writer.write('{"jsonrpc":"$jsonrpc.version","method":"$notif.method","params":'.bytes()) or {}
	$if T is Null {
		writer.write(jsonrpc.null_in_u8) or {}
	} $else {
		res := json.encode(notif.params)
		writer.write(res.bytes()) or {}
	}
	writer.write([u8(`}`)]) or {}
}
