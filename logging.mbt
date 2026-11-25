///|
/// MCP Structured Logging Levels (`logging/setLevel`) per MCP Specification.

///|
#derive(Eq, Debug)
pub(all) enum LogLevel {
  Debug
  Info
  Notice
  Warning
  Error
  Critical
}

///|
pub fn LogLevel::severity(self : LogLevel) -> Int32 {
  match self {
    Debug => 0
    Info => 1
    Notice => 2
    Warning => 3
    Error => 4
    Critical => 5
  }
}

///|
pub fn LogLevel::parse(raw : String) -> LogLevel? {
  match raw {
    "debug" => Some(Debug)
    "info" => Some(Info)
    "notice" => Some(Notice)
    "warning" => Some(Warning)
    "error" => Some(Error)
    "critical" => Some(Critical)
    _ => None
  }
}

///|
pub fn LogLevel::as_str(self : LogLevel) -> String {
  match self {
    Debug => "debug"
    Info => "info"
    Notice => "notice"
    Warning => "warning"
    Error => "error"
    Critical => "critical"
  }
}

///|
pub fn should_emit_log(configured : LogLevel, incoming : LogLevel) -> Bool {
  incoming.severity() >= configured.severity()
}
