//// A tiny, dependency-free JSON *encoder*.
////
//// Why hand-rolled instead of `gleam_json`: this server only ever encodes (never
//// decodes) JSON, and the published `gleam_json` versions are split awkwardly
//// around the gleam_stdlib 1.0 and OTP 27 boundaries. Our needs are small and
//// stable, so a self-contained encoder keeps the build portable across OTP
//// versions with zero external deps. (Decoding, when Phase 2 needs it, can pull a
//// real library pinned to the toolchain.)

import gleam/int
import gleam/list
import gleam/string

pub opaque type Json {
  JString(String)
  JInt(Int)
  JBool(Bool)
  JArray(List(Json))
  JObject(List(#(String, Json)))
}

pub fn string(value: String) -> Json {
  JString(value)
}

pub fn int(value: Int) -> Json {
  JInt(value)
}

pub fn bool(value: Bool) -> Json {
  JBool(value)
}

pub fn object(entries: List(#(String, Json))) -> Json {
  JObject(entries)
}

pub fn array(items: List(a), of encode: fn(a) -> Json) -> Json {
  JArray(list.map(items, encode))
}

pub fn to_string(json: Json) -> String {
  case json {
    JString(value) -> encode_string(value)
    JInt(value) -> int.to_string(value)
    JBool(True) -> "true"
    JBool(False) -> "false"
    JArray(items) -> "[" <> string.join(list.map(items, to_string), ",") <> "]"
    JObject(entries) ->
      "{" <> string.join(list.map(entries, encode_entry), ",") <> "}"
  }
}

fn encode_entry(entry: #(String, Json)) -> String {
  let #(key, value) = entry
  encode_string(key) <> ":" <> to_string(value)
}

fn encode_string(value: String) -> String {
  "\"" <> escape(value) <> "\""
}

fn escape(value: String) -> String {
  // Order matters: escape backslashes before quotes and control chars.
  value
  |> string.replace("\\", "\\\\")
  |> string.replace("\"", "\\\"")
  |> string.replace("\n", "\\n")
  |> string.replace("\r", "\\r")
  |> string.replace("\t", "\\t")
}
