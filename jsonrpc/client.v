module jsonrpc

// pub struct Client {
// mut:
// 	req_buf    strings.Builder = strings.new_builder(4096)
// 	conlen_buf strings.Builder = strings.new_builder(4096)
// 	res_buf    strings.Builder = strings.new_builder(4096)
// pub mut:
// 	stream       io.ReaderWriter
// }

// type jsonPrimitives = string | int | nil | bool
// type jsonArray = []jsonPrimitives
// type jsonObj = map[string]jsonPrimitives | map[string]jsonArray
// type jsonObject = map[string]

// pub fn (mut s Client) request[T](method string, params struct, id T) ! {
// 	req := Request{
// 		id: id.str()
// 		method: method
// 	}

// }