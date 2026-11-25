///|
/// Typed MCP JSON-RPC 2.0 Client Request Builders & Response Parsers.
/// Enables MoonBit WASM/JS/Native apps to act as MCP clients or run self-contained
/// round-trip protocol conformance tests.

///|
#derive(Eq, Debug)
pub(all) enum ClientResponse {
  Success(Json)
  RpcError(Int32, String)
  ProtocolError(String)
}

///|
pub fn build_initialize_request(
  id : Int32,
  client_name : String,
  client_version : String,
) -> String {
  json_obj([
    ("jsonrpc", Json::string("2.0")),
    ("id", Json::number(id.to_double())),
    ("method", Json::string("initialize")),
    (
      "params",
      json_obj([
        ("protocolVersion", Json::string("2025-03-26")),
        ("capabilities", json_obj([])),
        (
          "clientInfo",
          json_obj([
            ("name", Json::string(client_name)),
            ("version", Json::string(client_version)),
          ]),
        ),
      ]),
    ),
  ]).stringify()
}

///|
pub fn build_tools_call_request(
  id : Int32,
  tool_name : String,
  arguments : Json,
) -> String {
  json_obj([
    ("jsonrpc", Json::string("2.0")),
    ("id", Json::number(id.to_double())),
    ("method", Json::string("tools/call")),
    (
      "params",
      json_obj([("name", Json::string(tool_name)), ("arguments", arguments)]),
    ),
  ]).stringify()
}

///|
pub fn build_list_request(
  id : Int32,
  method_name : String,
  cursor : String?,
) -> String {
  let base : Array[(String, Json)] = [
    ("jsonrpc", Json::string("2.0")),
    ("id", Json::number(id.to_double())),
    ("method", Json::string(method_name)),
  ]
  match cursor {
    Some(c) => base.push(("params", json_obj([("cursor", Json::string(c))])))
    None => ()
  }
  json_obj(base).stringify()
}

///|
pub fn parse_client_response(raw : String) -> ClientResponse {
  let parsed = @json.parse(raw) catch {
    _ => return ProtocolError("invalid JSON response")
  }
  let obj = match parsed {
    Json::Object(m) => m
    _ => return ProtocolError("response root is not a JSON object")
  }
  match obj.get("error") {
    Some(Json::Object(err_obj)) => {
      let code = match err_obj.get("code") {
        Some(Json::Number(n, ..)) => n.to_int()
        _ => -32603
      }
      let msg = get_string_field(err_obj, "message").unwrap_or("unknown error")
      return RpcError(code, msg)
    }
    _ => ()
  }
  match obj.get("result") {
    Some(res) => Success(res)
    None => ProtocolError("response missing both 'result' and 'error'")
  }
}
