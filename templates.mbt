///|
/// MCP Dynamic Resource URI Templates (`resources/templates/list` + prefix/param matcher).

///|
#derive(Eq, Debug)
pub(all) struct ResourceTemplateDef {
  uri_template : String
  name : String
  description : String
  mime_type : String
}

///|
/// Match a concrete URI like `file:///workspace/README.md` against a single-placeholder
/// template like `file:///workspace/{path}` and extract `{ "path": "README.md" }`.
pub fn match_uri_template(
  template : String,
  uri : String,
) -> Map[String, String]? {
  let open_idx = match template.find("{") {
    Some(i) => i
    None => if template == uri { return Some(Map([])) } else { return None }
  }
  let close_idx = match template.find("}") {
    Some(i) if i > open_idx + 1 => i
    _ => return None
  }
  let prefix = template[:open_idx].to_owned()
  let param_name = template[open_idx + 1:close_idx].to_owned()
  let suffix = template[close_idx + 1:].to_owned()

  if !uri.has_prefix(prefix) || !uri.has_suffix(suffix) {
    return None
  }
  let val_start = prefix.length()
  let val_end = uri.length() - suffix.length()
  if val_end < val_start {
    return None
  }
  let val = uri[val_start:val_end].to_owned()
  if val.is_empty() {
    return None
  }
  let out : Map[String, String] = Map([])
  out[param_name] = val
  Some(out)
}
