///|
/// JSON-RPC 2.0 + Model Context Protocol (MCP 2024-11-05) Router.
/// Pure functional string-in / string-out dispatch — works identically on
/// WASM (browser/edge/WASI), JS (Node/Cloudflare Workers), and Native stdio.

///|
fn json_obj(entries : Array[(String, Json)]) -> Json {
  let m : Map[String, Json] = Map([])
  for entry in entries {
    let (k, v) = entry
    m[k] = v
  }
  Json::object(m)
}

///|
fn json_ok(id : Json, result : Json) -> String {
  json_obj([("jsonrpc", Json::string("2.0")), ("id", id), ("result", result)]).stringify()
}

///|
fn json_err(id : Json, code : Int32, message : String) -> String {
  json_obj([
    ("jsonrpc", Json::string("2.0")),
    ("id", id),
    (
      "error",
      json_obj([
        ("code", Json::number(code.to_double())),
        ("message", Json::string(message)),
      ]),
    ),
  ]).stringify()
}

///|
fn get_string_field(obj : Map[String, Json], key : String) -> String? {
  match obj.get(key) {
    Some(Json::String(s)) => Some(s)
    _ => None
  }
}

///|
fn McpServer::handle_initialize(self : McpServer, id : Json) -> String {
  let caps = json_obj([
    ("tools", json_obj([])),
    ("resources", json_obj([])),
    ("prompts", json_obj([])),
  ])
  let info = json_obj([
    ("name", Json::string(self.name)),
    ("version", Json::string(self.version)),
  ])
  json_ok(
    id,
    json_obj([
      ("protocolVersion", Json::string("2024-11-05")),
      ("capabilities", caps),
      ("serverInfo", info),
    ]),
  )
}

///|
fn McpServer::handle_tools_list(self : McpServer, id : Json) -> String {
  let arr : Array[Json] = []
  for t in self.tools {
    let annotations = json_obj([
      ("readOnlyHint", Json::boolean(t.risk_tier == ReadOnly)),
      ("destructiveHint", Json::boolean(t.risk_tier == Privileged)),
      ("riskTier", Json::string(t.risk_tier.label())),
    ])
    arr.push(
      json_obj([
        ("name", Json::string(t.name)),
        ("description", Json::string(t.description)),
        ("inputSchema", t.input_schema),
        ("annotations", annotations),
      ]),
    )
  }
  json_ok(id, json_obj([("tools", Json::array(arr))]))
}

///|
fn McpServer::handle_tools_call(
  self : McpServer,
  id : Json,
  params : Json?,
) -> String {
  let p_obj = match params {
    Some(Json::Object(m)) => m
    _ => return json_err(id, -32602, "Invalid params: expected object")
  }
  let tool_name = match get_string_field(p_obj, "name") {
    Some(n) => n
    None => return json_err(id, -32602, "Invalid params: missing tool 'name'")
  }
  let args = match p_obj.get("arguments") {
    Some(v) => v
    None => json_obj([])
  }

  for t in self.tools {
    if t.name == tool_name {
      // 1. Enforce Action Gateway risk tier ceiling
      if t.risk_tier.rank() > self.max_allowed_risk.rank() {
        let msg = "Action Gateway blocked tool '\{tool_name}' (risk=\{t.risk_tier.label()} > ceiling=\{self.max_allowed_risk.label()})"
        self.audit_log.push({
          method_name: "tools/call",
          target: tool_name,
          allowed: false,
          risk_tier: t.risk_tier.label(),
          note: msg,
        })
        let content = Json::array([
          json_obj([("type", Json::string("text")), ("text", Json::string(msg))]),
        ])
        return json_ok(
          id,
          json_obj([("content", content), ("isError", Json::boolean(true))]),
        )
      }

      // 2. Enforce session Write-Cap on mutating tools (SafeWrite / Privileged)
      if self.write_cap > 0 && t.risk_tier != ReadOnly {
        if self.write_count >= self.write_cap {
          let msg = "Write-Cap exceeded for tool '\{tool_name}' (used=\{self.write_count}/cap=\{self.write_cap})"
          self.audit_log.push({
            method_name: "tools/call",
            target: tool_name,
            allowed: false,
            risk_tier: t.risk_tier.label(),
            note: msg,
          })
          let content = Json::array([
            json_obj([
              ("type", Json::string("text")),
              ("text", Json::string(msg)),
            ]),
          ])
          return json_ok(
            id,
            json_obj([("content", content), ("isError", Json::boolean(true))]),
          )
        }
      }

      // 3. Deterministic JSON Schema argument validation
      match validate_arguments(t.input_schema, args) {
        Some(err_msg) => {
          self.audit_log.push({
            method_name: "tools/call",
            target: tool_name,
            allowed: false,
            risk_tier: t.risk_tier.label(),
            note: "schema_invalid: " + err_msg,
          })
          return json_err(id, -32602, "Invalid tool arguments: " + err_msg)
        }
        None => ()
      }

      if t.risk_tier != ReadOnly {
        self.write_count = self.write_count + 1
      }

      match (t.handler)(args) {
        Ok(text) => {
          self.audit_log.push({
            method_name: "tools/call",
            target: tool_name,
            allowed: true,
            risk_tier: t.risk_tier.label(),
            note: "ok",
          })
          let content = Json::array([
            json_obj([
              ("type", Json::string("text")),
              ("text", Json::string(text)),
            ]),
          ])
          return json_ok(
            id,
            json_obj([("content", content), ("isError", Json::boolean(false))]),
          )
        }
        Err(err_msg) => {
          self.audit_log.push({
            method_name: "tools/call",
            target: tool_name,
            allowed: true,
            risk_tier: t.risk_tier.label(),
            note: "error: " + err_msg,
          })
          let content = Json::array([
            json_obj([
              ("type", Json::string("text")),
              ("text", Json::string(err_msg)),
            ]),
          ])
          return json_ok(
            id,
            json_obj([("content", content), ("isError", Json::boolean(true))]),
          )
        }
      }
    }
  }

  json_err(id, -32602, "Unknown tool: " + tool_name)
}

///|
fn McpServer::handle_resources_list(self : McpServer, id : Json) -> String {
  let arr : Array[Json] = []
  for r in self.resources {
    arr.push(
      json_obj([
        ("uri", Json::string(r.uri)),
        ("name", Json::string(r.name)),
        ("description", Json::string(r.description)),
        ("mimeType", Json::string(r.mime_type)),
      ]),
    )
  }
  json_ok(id, json_obj([("resources", Json::array(arr))]))
}

///|
fn McpServer::handle_resources_read(
  self : McpServer,
  id : Json,
  params : Json?,
) -> String {
  let p_obj = match params {
    Some(Json::Object(m)) => m
    _ => return json_err(id, -32602, "Invalid params: expected object")
  }
  let uri = match get_string_field(p_obj, "uri") {
    Some(u) => u
    None => return json_err(id, -32602, "Invalid params: missing 'uri'")
  }
  for r in self.resources {
    if r.uri == uri {
      match (r.reader)() {
        Ok(text) => {
          self.audit_log.push({
            method_name: "resources/read",
            target: uri,
            allowed: true,
            risk_tier: "read_only",
            note: "ok",
          })
          let contents = Json::array([
            json_obj([
              ("uri", Json::string(r.uri)),
              ("mimeType", Json::string(r.mime_type)),
              ("text", Json::string(text)),
            ]),
          ])
          return json_ok(id, json_obj([("contents", contents)]))
        }
        Err(msg) => return json_err(id, -32000, msg)
      }
    }
  }
  json_err(id, -32002, "Resource not found: " + uri)
}

///|
fn McpServer::handle_prompts_list(self : McpServer, id : Json) -> String {
  let arr : Array[Json] = []
  for p in self.prompts {
    let args : Array[Json] = []
    for a in p.arguments {
      args.push(
        json_obj([
          ("name", Json::string(a.name)),
          ("description", Json::string(a.description)),
          ("required", Json::boolean(a.required)),
        ]),
      )
    }
    arr.push(
      json_obj([
        ("name", Json::string(p.name)),
        ("description", Json::string(p.description)),
        ("arguments", Json::array(args)),
      ]),
    )
  }
  json_ok(id, json_obj([("prompts", Json::array(arr))]))
}

///|
fn McpServer::handle_prompts_get(
  self : McpServer,
  id : Json,
  params : Json?,
) -> String {
  let p_obj = match params {
    Some(Json::Object(m)) => m
    _ => return json_err(id, -32602, "Invalid params: expected object")
  }
  let name = match get_string_field(p_obj, "name") {
    Some(n) => n
    None => return json_err(id, -32602, "Invalid params: missing prompt 'name'")
  }
  let arg_map : Map[String, String] = Map([])
  match p_obj.get("arguments") {
    Some(Json::Object(am)) =>
      for k, v in am {
        match v {
          Json::String(s) => arg_map[k] = s
          _ => arg_map[k] = v.stringify()
        }
      }
    _ => ()
  }
  for p in self.prompts {
    if p.name == name {
      for req_arg in p.arguments {
        if req_arg.required && arg_map.get(req_arg.name) is None {
          return json_err(
            id,
            -32602,
            "Missing required prompt argument: " + req_arg.name,
          )
        }
      }
      let rendered = (p.renderer)(arg_map)
      let messages = Json::array([
        json_obj([
          ("role", Json::string("user")),
          (
            "content",
            json_obj([
              ("type", Json::string("text")),
              ("text", Json::string(rendered)),
            ]),
          ),
        ]),
      ])
      return json_ok(
        id,
        json_obj([
          ("description", Json::string(p.description)),
          ("messages", messages),
        ]),
      )
    }
  }
  json_err(id, -32602, "Unknown prompt: " + name)
}

///|
fn McpServer::dispatch_object(
  self : McpServer,
  obj : Map[String, Json],
) -> String? {
  let method_name = match get_string_field(obj, "method") {
    Some(m) => m
    None =>
      return Some(
        json_err(Json::null(), -32600, "Invalid Request: missing 'method'"),
      )
  }

  // Notifications carry no response
  if method_name.has_prefix("notifications/") || obj.get("id") is None {
    return None
  }
  let id = match obj.get("id") {
    Some(v) => v
    None => Json::null()
  }
  let params = obj.get("params")

  let resp = match method_name {
    "initialize" => self.handle_initialize(id)
    "ping" => json_ok(id, json_obj([]))
    "tools/list" => self.handle_tools_list(id)
    "tools/call" => self.handle_tools_call(id, params)
    "resources/list" => self.handle_resources_list(id)
    "resources/read" => self.handle_resources_read(id, params)
    "prompts/list" => self.handle_prompts_list(id)
    "prompts/get" => self.handle_prompts_get(id, params)
    _ => json_err(id, -32601, "Method not found: " + method_name)
  }
  Some(resp)
}

///|
/// Main entry point: dispatch a single JSON-RPC 2.0 MCP message or JSON-RPC Batch array.
/// Returns `None` for notifications (or batch of pure notifications), `Some(json)` otherwise.
pub fn McpServer::handle_json(self : McpServer, raw : String) -> String? {
  let parsed = @json.parse(raw) catch {
    _ =>
      return Some(json_err(Json::null(), -32700, "Parse error: invalid JSON"))
  }
  match parsed {
    Json::Object(obj) => self.dispatch_object(obj)
    Json::Array(items) => {
      if items.is_empty() {
        return Some(
          json_err(Json::null(), -32600, "Invalid Request: empty batch array"),
        )
      }
      let responses : Array[String] = []
      for item in items {
        match item {
          Json::Object(obj) =>
            match self.dispatch_object(obj) {
              Some(r) => responses.push(r)
              None => ()
            }
          _ =>
            responses.push(
              json_err(
                Json::null(),
                -32600,
                "Invalid Request: batch element must be object",
              ),
            )
        }
      }
      if responses.is_empty() {
        None
      } else {
        Some("[" + responses.join(",") + "]")
      }
    }
    _ =>
      Some(
        json_err(
          Json::null(),
          -32600,
          "Invalid Request: expected JSON object or batch array",
        ),
      )
  }
}
