///|
/// Comprehensive blackbox test suite for `zhitongblog/moonbit-mcp-sdk`.

///|
fn build_demo_server() -> @moonbit-mcp-sdk.McpServer {
  let srv = @moonbit-mcp-sdk.McpServer::new("demo-mcp", "0.1.0")
  let word_schema = @moonbit-mcp-sdk.build_object_schema([
    {
      name: "text",
      kind: @moonbit-mcp-sdk.Str,
      description: "Input text to count",
      required: true,
    },
    {
      name: "min_len",
      kind: @moonbit-mcp-sdk.Num,
      description: "Optional minimum word length",
      required: false,
    },
  ])
  let note_schema = @moonbit-mcp-sdk.build_object_schema([
    {
      name: "title",
      kind: @moonbit-mcp-sdk.Str,
      description: "Note title",
      required: true,
    },
  ])
  let empty_schema = @moonbit-mcp-sdk.build_object_schema([])

  srv.register_tool(
    "word_count",
    "Count words in a text payload",
    word_schema,
    @moonbit-mcp-sdk.ReadOnly,
    fn(args) {
      match args {
        Json::Object(m) =>
          match m.get("text") {
            Some(Json::String(s)) => {
              let parts = s.split(" ").filter(fn(w) { !w.is_empty() }).collect()
              @moonbit-mcp-sdk.Ok("words=\{parts.length()}")
            }
            _ => @moonbit-mcp-sdk.Err("missing 'text' argument")
          }
        _ => @moonbit-mcp-sdk.Err("expected object arguments")
      }
    },
  )

  srv.register_tool(
    "save_note",
    "Write a note inside sandbox",
    note_schema,
    @moonbit-mcp-sdk.SafeWrite,
    fn(args) {
      match args {
        Json::Object(m) =>
          match m.get("title") {
            Some(Json::String(t)) => @moonbit-mcp-sdk.Ok("saved:" + t)
            _ => @moonbit-mcp-sdk.Err("missing title")
          }
        _ => @moonbit-mcp-sdk.Err("bad args")
      }
    },
  )

  srv.register_tool(
    "danger_shell",
    "Privileged command execution gated by Action Gateway",
    empty_schema,
    @moonbit-mcp-sdk.Privileged,
    fn(_) { @moonbit-mcp-sdk.Ok("executed") },
  )

  srv.register_tool(
    "always_fail",
    "Tool returning structured domain error",
    empty_schema,
    @moonbit-mcp-sdk.ReadOnly,
    fn(_) { @moonbit-mcp-sdk.Err("downstream timeout") },
  )

  srv.register_resource(
    "mcp://health/status",
    "Health Status",
    "Runtime health metadata",
    "application/json",
    fn() { @moonbit-mcp-sdk.Ok("{\"ok\":true,\"runtime\":\"moonbit-wasm\"}") },
  )

  srv.register_prompt(
    "audit-skill",
    "Security review checklist skill",
    [{ name: "repo", description: "Target repository name", required: true, }],
    fn(args) {
      let repo = args.get("repo").unwrap_or("unknown")
      "Run deterministic security audit on repository: \{repo}"
    },
  )

  srv
}

///|
test "initialize and ping return valid MCP JSON-RPC responses" {
  let srv = build_demo_server()
  let init_resp = srv
    .handle_json("{\"jsonrpc\":\"2.0\",\"id\":1,\"method\":\"initialize\"}")
    .unwrap()
  assert_true(init_resp.contains("\"protocolVersion\":\"2024-11-05\""))
  assert_true(init_resp.contains("\"name\":\"demo-mcp\""))
  assert_eq(srv.tool_count(), 4)

  let ping_resp = srv.handle_json(
    "{\"jsonrpc\":\"2.0\",\"id\":\"req-ping\",\"method\":\"ping\"}",
  )
  assert_true(ping_resp.unwrap().contains("\"id\":\"req-ping\""))
}

///|
test "notifications return None without reply" {
  let srv = build_demo_server()
  assert_eq(
    srv.handle_json(
      "{\"jsonrpc\":\"2.0\",\"method\":\"notifications/initialized\"}",
    ),
    None,
  )
  assert_eq(srv.handle_json("{\"jsonrpc\":\"2.0\",\"method\":\"ping\"}"), None)
}

///|
test "tools/list exposes JSON Schemas and Action Gateway annotations" {
  let srv = build_demo_server()
  let resp = srv
    .handle_json("{\"jsonrpc\":\"2.0\",\"id\":3,\"method\":\"tools/list\"}")
    .unwrap()
  assert_true(resp.contains("\"word_count\""))
  assert_true(resp.contains("\"required\":[\"text\"]"))
  assert_true(resp.contains("\"riskTier\":\"privileged\""))
  assert_true(resp.contains("\"readOnlyHint\":true"))
}

///|
test "tools/call executes safe tool and blocks privileged tool via Action Gateway" {
  let srv = build_demo_server()
  let ok_resp = srv
    .handle_json(
      "{\"jsonrpc\":\"2.0\",\"id\":4,\"method\":\"tools/call\",\"params\":{\"name\":\"word_count\",\"arguments\":{\"text\":\"moonbit mcp sdk rocks\"}}}",
    )
    .unwrap()
  assert_true(ok_resp.contains("words=4"))
  assert_true(ok_resp.contains("\"isError\":false"))

  let blocked = srv
    .handle_json(
      "{\"jsonrpc\":\"2.0\",\"id\":5,\"method\":\"tools/call\",\"params\":{\"name\":\"danger_shell\",\"arguments\":{}}}",
    )
    .unwrap()
  assert_true(blocked.contains("Action Gateway blocked tool 'danger_shell'"))
  assert_true(blocked.contains("\"isError\":true"))
  assert_eq(srv.get_audit_log().length(), 2)
}

///|
test "schema validator rejects missing required args and type mismatches before handler" {
  let srv = build_demo_server()
  let missing = srv
    .handle_json(
      "{\"jsonrpc\":\"2.0\",\"id\":10,\"method\":\"tools/call\",\"params\":{\"name\":\"word_count\",\"arguments\":{}}}",
    )
    .unwrap()
  assert_true(missing.contains("-32602"))
  assert_true(missing.contains("missing required argument 'text'"))

  let bad_type = srv
    .handle_json(
      "{\"jsonrpc\":\"2.0\",\"id\":11,\"method\":\"tools/call\",\"params\":{\"name\":\"word_count\",\"arguments\":{\"text\":123}}}",
    )
    .unwrap()
  assert_true(bad_type.contains("-32602"))
  assert_true(bad_type.contains("expected type 'string'"))

  let bad_opt = srv
    .handle_json(
      "{\"jsonrpc\":\"2.0\",\"id\":12,\"method\":\"tools/call\",\"params\":{\"name\":\"word_count\",\"arguments\":{\"text\":\"ok\",\"min_len\":\"five\"}}}",
    )
    .unwrap()
  assert_true(bad_opt.contains("expected type 'number'"))
}

///|
test "write-cap blocks excess mutating calls and allows reset after checkpoint" {
  let srv = build_demo_server()
  srv.set_write_cap(1)

  let first = srv
    .handle_json(
      "{\"jsonrpc\":\"2.0\",\"id\":20,\"method\":\"tools/call\",\"params\":{\"name\":\"save_note\",\"arguments\":{\"title\":\"v1\"}}}",
    )
    .unwrap()
  assert_true(first.contains("saved:v1"))

  let second = srv
    .handle_json(
      "{\"jsonrpc\":\"2.0\",\"id\":21,\"method\":\"tools/call\",\"params\":{\"name\":\"save_note\",\"arguments\":{\"title\":\"v2\"}}}",
    )
    .unwrap()
  assert_true(second.contains("Write-Cap exceeded"))
  assert_true(second.contains("\"isError\":true"))

  // ReadOnly tools remain unaffected by write-cap
  let ro = srv
    .handle_json(
      "{\"jsonrpc\":\"2.0\",\"id\":22,\"method\":\"tools/call\",\"params\":{\"name\":\"word_count\",\"arguments\":{\"text\":\"still allowed\"}}}",
    )
    .unwrap()
  assert_true(ro.contains("words=2"))

  // Resetting write count unlocks mutations again
  srv.reset_write_count()
  let third = srv
    .handle_json(
      "{\"jsonrpc\":\"2.0\",\"id\":23,\"method\":\"tools/call\",\"params\":{\"name\":\"save_note\",\"arguments\":{\"title\":\"v3\"}}}",
    )
    .unwrap()
  assert_true(third.contains("saved:v3"))
}

///|
test "raising risk ceiling unlocks privileged tool" {
  let srv = build_demo_server()
  srv.set_max_risk(@moonbit-mcp-sdk.Privileged)
  let resp = srv
    .handle_json(
      "{\"jsonrpc\":\"2.0\",\"id\":30,\"method\":\"tools/call\",\"params\":{\"name\":\"danger_shell\",\"arguments\":{}}}",
    )
    .unwrap()
  assert_true(resp.contains("executed"))
  assert_true(resp.contains("\"isError\":false"))
}

///|
test "domain tool error sets isError=true and logs audit note" {
  let srv = build_demo_server()
  let resp = srv
    .handle_json(
      "{\"jsonrpc\":\"2.0\",\"id\":31,\"method\":\"tools/call\",\"params\":{\"name\":\"always_fail\",\"arguments\":{}}}",
    )
    .unwrap()
  assert_true(resp.contains("downstream timeout"))
  assert_true(resp.contains("\"isError\":true"))
  let jsonl = srv.export_audit_jsonl()
  assert_true(jsonl.contains("always_fail"))
  assert_true(jsonl.contains("downstream timeout"))
}

///|
test "JSON-RPC batch requests handle mixed requests, notifications, and invalid items" {
  let srv = build_demo_server()
  let batch = "[{\"jsonrpc\":\"2.0\",\"id\":1,\"method\":\"ping\"},{\"jsonrpc\":\"2.0\",\"method\":\"notifications/initialized\"},{\"jsonrpc\":\"2.0\",\"id\":2,\"method\":\"tools/call\",\"params\":{\"name\":\"word_count\",\"arguments\":{\"text\":\"a b c\"}}}]"
  let resp = srv.handle_json(batch).unwrap()
  assert_true(resp.has_prefix("["))
  assert_true(resp.contains("\"id\":1"))
  assert_true(resp.contains("words=3"))

  let empty_batch = srv.handle_json("[]").unwrap()
  assert_true(empty_batch.contains("-32600"))

  let pure_notif_batch = srv.handle_json(
    "[{\"jsonrpc\":\"2.0\",\"method\":\"notifications/initialized\"}]",
  )
  assert_eq(pure_notif_batch, None)
}

///|
test "resources/list and resources/read work and handle missing URI" {
  let srv = build_demo_server()
  let list = srv
    .handle_json(
      "{\"jsonrpc\":\"2.0\",\"id\":40,\"method\":\"resources/list\"}",
    )
    .unwrap()
  assert_true(list.contains("mcp://health/status"))

  let read = srv
    .handle_json(
      "{\"jsonrpc\":\"2.0\",\"id\":41,\"method\":\"resources/read\",\"params\":{\"uri\":\"mcp://health/status\"}}",
    )
    .unwrap()
  assert_true(read.contains("moonbit-wasm"))

  let missing = srv
    .handle_json(
      "{\"jsonrpc\":\"2.0\",\"id\":42,\"method\":\"resources/read\",\"params\":{\"uri\":\"mcp://nope\"}}",
    )
    .unwrap()
  assert_true(missing.contains("-32002"))
}

///|
test "prompts/list and prompts/get render native MCP skills and enforce required args" {
  let srv = build_demo_server()
  let list = srv
    .handle_json("{\"jsonrpc\":\"2.0\",\"id\":50,\"method\":\"prompts/list\"}")
    .unwrap()
  assert_true(list.contains("audit-skill"))

  let ok = srv
    .handle_json(
      "{\"jsonrpc\":\"2.0\",\"id\":51,\"method\":\"prompts/get\",\"params\":{\"name\":\"audit-skill\",\"arguments\":{\"repo\":\"solomd\"}}}",
    )
    .unwrap()
  assert_true(
    ok.contains("Run deterministic security audit on repository: solomd"),
  )

  let missing_arg = srv
    .handle_json(
      "{\"jsonrpc\":\"2.0\",\"id\":52,\"method\":\"prompts/get\",\"params\":{\"name\":\"audit-skill\",\"arguments\":{}}}",
    )
    .unwrap()
  assert_true(missing_arg.contains("-32602"))
}

///|
test "invalid JSON, unknown methods, and unknown tools return standard JSON-RPC errors" {
  let srv = build_demo_server()
  assert_true(srv.handle_json("{broken").unwrap().contains("-32700"))
  assert_true(srv.handle_json("42").unwrap().contains("-32600"))
  assert_true(
    srv
    .handle_json("{\"jsonrpc\":\"2.0\",\"id\":60,\"method\":\"foo/bar\"}")
    .unwrap()
    .contains("-32601"),
  )
  assert_true(
    srv
    .handle_json(
      "{\"jsonrpc\":\"2.0\",\"id\":61,\"method\":\"tools/call\",\"params\":{\"name\":\"nonexistent\",\"arguments\":{}}}",
    )
    .unwrap()
    .contains("-32602"),
  )
}
