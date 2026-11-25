///|
/// Ergonomic JSON Schema Builder & Deterministic Runtime Argument Validator
/// for Model Context Protocol (MCP) tool inputs.

///|
#derive(Eq, Debug)
pub(all) enum SchemaType {
  Str
  Num
  Bool
  Obj
  Arr
}

///|
pub fn SchemaType::as_str(self : SchemaType) -> String {
  match self {
    Str => "string"
    Num => "number"
    Bool => "boolean"
    Obj => "object"
    Arr => "array"
  }
}

///|
#derive(Eq, Debug)
pub(all) struct PropSpec {
  name : String
  kind : SchemaType
  description : String
  required : Bool
}

///|
/// Build a standard JSON Schema (`type: "object"`) from typed property specs.
pub fn build_object_schema(props : Array[PropSpec]) -> Json {
  let prop_map : Map[String, Json] = Map([])
  let req_arr : Array[Json] = []
  for p in props {
    prop_map[p.name] = json_obj([
      ("type", Json::string(p.kind.as_str())),
      ("description", Json::string(p.description)),
    ])
    if p.required {
      req_arr.push(Json::string(p.name))
    }
  }
  json_obj([
    ("type", Json::string("object")),
    ("properties", Json::object(prop_map)),
    ("required", Json::array(req_arr)),
  ])
}

///|
fn json_matches_type(val : Json, expected : String) -> Bool {
  match (val, expected) {
    (Json::String(_), "string") => true
    (Json::Number(_), "number") => true
    (Json::Number(_), "integer") => true
    (Json::True, "boolean") => true
    (Json::False, "boolean") => true
    (Json::Object(_), "object") => true
    (Json::Array(_), "array") => true
    (Json::Null, "null") => true
    _ => false
  }
}

///|
/// Deterministically validate `args` against a tool's `input_schema` BEFORE executing the handler.
/// Checks: root type == object, all `required` keys present, and declared `properties.<k>.type` matches.
pub fn validate_arguments(schema : Json, args : Json) -> String? {
  let s_obj = match schema {
    Json::Object(m) => m
    _ => return None
  }
  let a_obj = match args {
    Json::Object(m) => m
    _ => return Some("arguments must be a JSON object")
  }

  // 1. Check required keys
  match s_obj.get("required") {
    Some(Json::Array(req_list)) =>
      for item in req_list {
        match item {
          Json::String(key) =>
            if a_obj.get(key) is None {
              return Some("missing required argument '\{key}'")
            }
          _ => ()
        }
      }
    _ => ()
  }

  // 2. Check declared property types
  match s_obj.get("properties") {
    Some(Json::Object(prop_map)) =>
      for key, val in a_obj {
        match prop_map.get(key) {
          Some(Json::Object(spec)) =>
            match get_string_field(spec, "type") {
              Some(expected_ty) =>
                if !json_matches_type(val, expected_ty) {
                  return Some(
                    "argument '\{key}' expected type '\{expected_ty}'",
                  )
                }
              None => ()
            }
          _ => ()
        }
      }
    _ => ()
  }

  None
}
