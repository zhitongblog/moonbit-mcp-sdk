///|
/// Core Model Context Protocol (MCP) types, Action-Gateway risk tiers,
/// and registry definitions for MoonBit WASM/JS/Native runtimes.

///|
#derive(Eq, Debug)
pub(all) enum RiskTier {
  ReadOnly
  SafeWrite
  Privileged
}

///|
pub fn RiskTier::rank(self : RiskTier) -> Int32 {
  match self {
    ReadOnly => 0
    SafeWrite => 1
    Privileged => 2
  }
}

///|
pub fn RiskTier::label(self : RiskTier) -> String {
  match self {
    ReadOnly => "read_only"
    SafeWrite => "safe_write"
    Privileged => "privileged"
  }
}

///|
#derive(Eq, Debug)
pub(all) enum ToolResult {
  Ok(String)
  Err(String)
}

///|
#derive(Eq, Debug)
pub(all) struct AuditEntry {
  method_name : String
  target : String
  allowed : Bool
  risk_tier : String
  note : String
}

///|
pub(all) struct ToolDef {
  name : String
  description : String
  input_schema : Json
  risk_tier : RiskTier
  handler : (Json) -> ToolResult
}

///|
pub(all) struct ResourceDef {
  uri : String
  name : String
  description : String
  mime_type : String
  reader : () -> ToolResult
}

///|
#derive(Eq, Debug)
pub(all) struct PromptArg {
  name : String
  description : String
  required : Bool
}

///|
pub(all) struct PromptDef {
  name : String
  description : String
  arguments : Array[PromptArg]
  renderer : (Map[String, String]) -> String
}

///|
pub struct McpServer {
  name : String
  version : String
  mut max_allowed_risk : RiskTier
  mut write_cap : Int32
  mut write_count : Int32
  tools : Array[ToolDef]
  resources : Array[ResourceDef]
  prompts : Array[PromptDef]
  audit_log : Array[AuditEntry]
}

///|
pub fn McpServer::new(name : String, version : String) -> McpServer {
  {
    name,
    version,
    max_allowed_risk: SafeWrite,
    write_cap: 0,
    write_count: 0,
    tools: [],
    resources: [],
    prompts: [],
    audit_log: [],
  }
}

///|
/// Configure the Action Gateway risk ceiling (default: SafeWrite, blocking Privileged tools).
pub fn McpServer::set_max_risk(self : McpServer, tier : RiskTier) -> Unit {
  self.max_allowed_risk = tier
}

///|
/// Configure a session-wide write-cap (0 = unlimited; >0 caps total SafeWrite/Privileged calls).
pub fn McpServer::set_write_cap(self : McpServer, cap : Int32) -> Unit {
  self.write_cap = cap
}

///|
/// Reset the session write counter (e.g., after human approval checkpoint).
pub fn McpServer::reset_write_count(self : McpServer) -> Unit {
  self.write_count = 0
}

///|
/// Export the complete audit log as newline-delimited JSON (JSONL).
pub fn McpServer::export_audit_jsonl(self : McpServer) -> String {
  let lines : Array[String] = []
  for e in self.audit_log {
    lines.push(
      json_obj([
        ("method", Json::string(e.method_name)),
        ("target", Json::string(e.target)),
        ("allowed", Json::boolean(e.allowed)),
        ("riskTier", Json::string(e.risk_tier)),
        ("note", Json::string(e.note)),
      ]).stringify(),
    )
  }
  lines.join("\n")
}

///|
pub fn McpServer::register_tool(
  self : McpServer,
  name : String,
  description : String,
  input_schema : Json,
  risk_tier : RiskTier,
  handler : (Json) -> ToolResult,
) -> Unit {
  self.tools.push({ name, description, input_schema, risk_tier, handler, })
}

///|
pub fn McpServer::register_resource(
  self : McpServer,
  uri : String,
  name : String,
  description : String,
  mime_type : String,
  reader : () -> ToolResult,
) -> Unit {
  self.resources.push({ uri, name, description, mime_type, reader, })
}

///|
pub fn McpServer::register_prompt(
  self : McpServer,
  name : String,
  description : String,
  arguments : Array[PromptArg],
  renderer : (Map[String, String]) -> String,
) -> Unit {
  self.prompts.push({ name, description, arguments, renderer, })
}

///|
pub fn McpServer::get_audit_log(self : McpServer) -> Array[AuditEntry] {
  self.audit_log
}

///|
pub fn McpServer::tool_count(self : McpServer) -> Int32 {
  self.tools.length()
}
