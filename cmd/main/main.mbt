///|
/// Runnable demo for `zhitongblog/moonbit-mcp-sdk` (WASM / JS / Native).
fn main {
  let srv = @mcp.McpServer::new("moonbit-mcp-demo", "0.2.0")
  srv.set_instructions(
    "Prefer ReadOnly tools; Privileged tools require elevated gateway policy.",
  )
  srv.set_page_size(2)

  let echo_schema = @mcp.build_object_schema([
    {
      name: "message",
      kind: @mcp.Str,
      description: "Message to echo back",
      required: true,
    },
  ])
  let empty_schema = @mcp.build_object_schema([])

  srv.register_tool(
    "echo",
    "Echoes back the provided message",
    echo_schema,
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
    empty_schema,
    @mcp.Privileged,
    fn(_) { @mcp.Ok("dropped") },
  )

  srv.register_resource_template(
    "workspace://files/{path}", "Workspace File Template", "Dynamic URI template for workspace documents",
    "text/plain",
  )

  let reqs = [
    @mcp.build_initialize_request(1, "moonbit-demo-client", "0.2.0"),
    @mcp.build_list_request(2, "tools/list", None),
    "{\"jsonrpc\":\"2.0\",\"id\":3,\"method\":\"resources/templates/list\"}",
    "{\"jsonrpc\":\"2.0\",\"id\":4,\"method\":\"logging/setLevel\",\"params\":{\"level\":\"warning\"}}",
    "{\"jsonrpc\":\"2.0\",\"id\":5,\"method\":\"tools/call\",\"params\":{\"name\":\"echo\",\"arguments\":{\"message\":\"Hello MoonBit MCP!\"}}}",
    "{\"jsonrpc\":\"2.0\",\"id\":6,\"method\":\"tools/call\",\"params\":{\"name\":\"drop_database\",\"arguments\":{}}}",
  ]

  println("=== MoonBit WASM-Native MCP SDK Demo ===")
  for r in reqs {
    match srv.handle_json(r) {
      Some(resp) => println(resp)
      None => ()
    }
  }
  let echo_calls = srv.get_tool_call_count("echo")
  let audit_len = srv.get_audit_log().length()
  println("Echo calls: \{echo_calls}, Audit trail entries: \{audit_len}")
}
