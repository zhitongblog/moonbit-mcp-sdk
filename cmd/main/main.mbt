///|
/// Runnable demo for `zhitongblog/moonbit-mcp-sdk` (WASM / JS / Native).
fn main {
  let srv = @mcp.McpServer::new("moonbit-mcp-demo", "0.1.0")
  let schema = Json::object({ "type": Json::string("object") })

  srv.register_tool(
    "echo",
    "Echoes back the provided message",
    schema,
    @mcp.ReadOnly,
    fn(args) {
      match args {
        Json::Object(m) =>
          match m.get("message") {
            Some(Json::String(s)) => @mcp.Ok("echo: " + s)
            _ => @mcp.Err("missing 'message'")
          }
        _ => @mcp.Err("expected JSON object")
      }
    },
  )

  srv.register_tool(
    "drop_database",
    "Privileged operation blocked by default Action Gateway",
    schema,
    @mcp.Privileged,
    fn(_) { @mcp.Ok("dropped") },
  )

  let reqs = [
    "{\"jsonrpc\":\"2.0\",\"id\":1,\"method\":\"initialize\"}", "{\"jsonrpc\":\"2.0\",\"id\":2,\"method\":\"tools/list\"}",
    "{\"jsonrpc\":\"2.0\",\"id\":3,\"method\":\"tools/call\",\"params\":{\"name\":\"echo\",\"arguments\":{\"message\":\"Hello MoonBit MCP!\"}}}",
    "{\"jsonrpc\":\"2.0\",\"id\":4,\"method\":\"tools/call\",\"params\":{\"name\":\"drop_database\",\"arguments\":{}}}",
  ]

  println("=== MoonBit WASM-Native MCP SDK Demo ===")
  for r in reqs {
    match srv.handle_json(r) {
      Some(resp) => println(resp)
      None => ()
    }
  }
  println("Audit trail entries: \{srv.get_audit_log().length()}")
}
