module jsonrpc

import io

pub struct Client {
pub mut:
	stream io.ReaderWriter
}

pub fn (mut c Client) notify[T](method string, params T) ! {
	c.stream.write(new_notification(method, params).encode().bytes()) or { return err }
}

pub fn (mut c Client) request[T](method string, params T, id string) !Response {
	c.stream.write(new_request(method, params, id).encode().bytes()) or { return err }

	mut rx := []u8{len: 4096}
	bytes_read := c.stream.read(mut rx) or {
		return err
	}

	resp_str := rx.bytestr()

	return decode_response(resp_str)
}

pub fn (mut c Client) batch(reqs []Request, notifs []Notification) ![]Response {
	mut reqs_str := "["
	for req in reqs {
		reqs_str = reqs_str + req.encode() + ", "
	}
	for notif in notifs {
		reqs_str = reqs_str + notif.encode() + ", "
	}
	reqs_str = reqs_str.all_before_last(", ") + "]"
	c.stream.write(reqs_str.bytes()) or { return err }

	mut rx := []u8{len: 4096}
	bytes_read := c.stream.read(mut rx) or {
		return err
	}

	resp_str := rx.bytestr()

	return decode_batch_response(resp_str)
}