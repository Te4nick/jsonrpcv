module main

import net
import sync
import jsonrpc

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

fn (mut h KvHandler) handle_jsonrpc(req &jsonrpc.Request, mut wr jsonrpc.ResponseWriter) ! {
	match req.method {
		'kv.create' {
			p := req.decode_params[KvCreateParams]() or {
				return jsonrpc.invalid_params
			}
			if p.key.len == 0 {
				return jsonrpc.invalid_params
			}
			h.mu.@lock()
			defer { h.mu.unlock() }
			if p.key in h.store {
				// custom app-level error code
				return jsonrpc.ResponseError{
					code: -32010
					message: 'Key already exists'
					data: p.key
				}
			}
			h.store[p.key] = p.value
			wr.write({ 'ok': true })
		}
		'kv.get' {
			p := req.decode_params[KvKeyParams]() or {
				return jsonrpc.invalid_params
			}
			h.mu.@lock()
			defer { h.mu.unlock() }
			if p.key !in h.store {
				return jsonrpc.ResponseError{
					code: -32004
					message: 'Not found'
					data: p.key
				}
			}
			wr.write(KvItem{ key: p.key, value: h.store[p.key] })
		}
		'kv.update' {
			p := req.decode_params[KvUpdateParams]() or {
				return jsonrpc.invalid_params
			}
			h.mu.@lock()
			defer { h.mu.unlock() }
			if p.key !in h.store {
				return jsonrpc.ResponseError{
					code: -32004
					message: 'Not found'
					data: p.key
				}
			}
			h.store[p.key] = p.value
			wr.write({ 'ok': true })
		}
		'kv.delete' {
			p := req.decode_params[KvKeyParams]() or {
				return jsonrpc.invalid_params
			}
			h.mu.@lock()
			defer { h.mu.unlock() }
			if p.key !in h.store {
				return jsonrpc.ResponseError{
					code: -32004
					message: 'Not found'
					data: p.key
				}
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
			return jsonrpc.method_not_found
		}
	}
}

// ---- Per-connection server loop ----
// The jsonrpc.Server.start() reads from stream and writes to same stream. :contentReference[oaicite:9]{index=9}
fn handle_conn(mut conn net.TcpConn) {
	defer { conn.close() or {} }

	mut srv := jsonrpc.Server{
		stream: conn
		handler: KvHandler{
			store: map[string]string{}
		}
		interceptors: [
			jsonrpc.LoggingInterceptor{},
		]
	}

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
