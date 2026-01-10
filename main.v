module main

import net
import sync
import jsonrpc
import log

// ---- CRUD domain ----
struct KvCreateParams {
	key   string
	value string
}

struct KvKeyParams {
	key string
}

struct KvUpdateParams {
	key   string
	value string
}

struct KvItem {
	key   string
	value string
}

// ---- Handler ----
struct KvHandler {
mut:
	mu    sync.Mutex
	store map[string]string
}

fn (mut h KvHandler) handle_jsonrpc(req &jsonrpc.Request, mut wr jsonrpc.ResponseWriter) {
	match req.method {
		'kv.create' {
			p := req.decode_params[KvCreateParams]() or {
				wr.write_error(jsonrpc.invalid_params)
				return
			}
			if p.key.len == 0 {
				wr.write_error(jsonrpc.invalid_params)
				return
			}
			h.mu.@lock()
			defer { h.mu.unlock() }
			if p.key in h.store {
				// custom app-level error code
				wr.write_error(jsonrpc.ResponseError{
					code: -32010
					message: 'Key already exists'
					data: p.key
				})
				return
			}
			h.store[p.key] = p.value
			wr.write({ 'ok': true })
		}
		'kv.get' {
			p := req.decode_params[KvKeyParams]() or {
				wr.write_error(jsonrpc.invalid_params)
				return
			}
			h.mu.@lock()
			defer { h.mu.unlock() }
			if p.key !in h.store {
				wr.write_error(jsonrpc.ResponseError{
					code: -32004
					message: 'Not found'
					data: p.key
				})
				return
			}
			wr.write(KvItem{ key: p.key, value: h.store[p.key] })
		}
		'kv.update' {
			p := req.decode_params[KvUpdateParams]() or {
				wr.write_error(jsonrpc.invalid_params)
				return
			}
			h.mu.@lock()
			defer { h.mu.unlock() }
			if p.key !in h.store {
				wr.write_error(jsonrpc.ResponseError{
					code: -32004
					message: 'Not found'
					data: p.key
				})
				return
			}
			h.store[p.key] = p.value
			wr.write({ 'ok': true })
		}
		'kv.delete' {
			p := req.decode_params[KvKeyParams]() or {
				wr.write_error(jsonrpc.invalid_params)
				return
			}
			h.mu.@lock()
			defer { h.mu.unlock() }
			if p.key !in h.store {
				wr.write_error(jsonrpc.ResponseError{
					code: -32004
					message: 'Not found'
					data: p.key
				})
				return
			}
			h.store.delete(p.key)
			wr.write({ 'ok': true })
		}
		'kv.list' {
			h.mu.@lock()
			defer { h.mu.unlock() }
			mut items := []KvItem{}
			for k, v in h.store {
				items << KvItem{ key: k, value: v }
			}
			items.sort(a.key < b.key)
			wr.write(items)
		}
		else {
			wr.write_error(jsonrpc.method_not_found)
		}
	}
}

pub fn on_event_logger(name string, data string) ! {
	msg := '[EVENT] name=${name} data=${data}'
	mut l := log.new_thread_safe_log()
	l.debug(msg)
}

// ---- Per-connection server loop ----
// The jsonrpc.Server.start() reads from stream and writes to same stream. :contentReference[oaicite:9]{index=9}
fn handle_conn(mut conn net.TcpConn) {
	defer { conn.close() or {} }

	mut log_inter := jsonrpc.LoggingInterceptor{}
	// inters := jsonrpc.Interceptors{
	// 	event: [on_event_logger]
	// 	// encoded_request: [log_inter.on_encoded_request]
	// 	// request: [log_inter.on_request]
	// 	// response: [log_inter.on_response]
	// 	// encoded_response: [log_inter.on_encoded_response]
	// }

	mut srv := jsonrpc.new_server(jsonrpc.ServerConfig{
		stream: conn
		handler: KvHandler{
			store: map[string]string{}
		}
		//interceptors: [log_inter]
		encreqint: [log_inter]
		reqint: [log_inter]
		respint: [log_inter]
		encrespint: [log_inter]
	})

	srv.start()
}

fn main() {
	addr := '127.0.0.1:42228'
	mut l := net.listen_tcp(.ip, addr)!
	println('TCP JSON-RPC server on ${addr} (Content-Length framing)')

	for {
		mut c := l.accept()!
		println("Accepted")
		go handle_conn(mut c)
	}
}
