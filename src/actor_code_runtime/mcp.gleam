//// Minimal MCP (Model Context Protocol) request handling over JSON-RPC.
////
//// `handle/1` takes one line of JSON-RPC input and returns one line of output.
//// The tool logic it routes to (the `tools` and `runtime` modules) is fully
//// typed and unit-tested.
////
//// NOTE (scaffold): method/tool routing is done by substring match and the
//// request `id` is not yet echoed. Proper JSON-RPC decoding (id + params) is a
//// Phase-2 TODO using the resolved gleam_json decoder API.

import actor_code_runtime/json.{type Json}
import actor_code_runtime/tools
import gleam/string

pub const protocol_version = "2024-11-05"

pub const server_name = "actor-code-runtime"

pub const server_version = "0.1.0"

type Method {
  Initialize
  ListTools
  CallTool
  Unknown
}

pub fn handle(line: String) -> String {
  json.to_string(route(line))
}

fn route(line: String) -> Json {
  case classify(line) {
    Initialize -> initialize_result()
    ListTools -> list_tools_result()
    CallTool -> call_tool_result(line)
    Unknown -> method_not_found()
  }
}

fn classify(line: String) -> Method {
  case
    string.contains(line, "\"initialize\""),
    string.contains(line, "tools/list"),
    string.contains(line, "tools/call")
  {
    True, _, _ -> Initialize
    _, True, _ -> ListTools
    _, _, True -> CallTool
    _, _, _ -> Unknown
  }
}

fn ok(result: Json) -> Json {
  json.object([#("jsonrpc", json.string("2.0")), #("result", result)])
}

fn initialize_result() -> Json {
  ok(
    json.object([
      #("protocolVersion", json.string(protocol_version)),
      #(
        "serverInfo",
        json.object([
          #("name", json.string(server_name)),
          #("version", json.string(server_version)),
        ]),
      ),
      #("capabilities", json.object([#("tools", json.object([]))])),
    ]),
  )
}

fn list_tools_result() -> Json {
  ok(json.object([#("tools", json.array(tools.all(), tools.to_json))]))
}

fn call_tool_result(line: String) -> Json {
  let tool = case tools.from_name(extract_tool_name(line)) {
    Ok(t) -> t
    Error(_) -> tools.RunCode
  }
  // The execution engine (runtime.run) is implemented and tested; wiring the
  // decoded request parameters (code / command / diff) into it is the next
  // increment, so this acknowledges the tool rather than executing empty input.
  let text =
    "actor-code-runtime recognizes "
    <> tools.name(tool)
    <> "; request-parameter decoding is the next increment."
  ok(
    json.object([
      #("content", json.array([text_content(text)], fn(content) { content })),
      #("isError", json.bool(False)),
    ]),
  )
}

fn extract_tool_name(line: String) -> String {
  case string.contains(line, "run_tests"), string.contains(line, "evaluate") {
    True, _ -> "run_tests"
    _, True -> "evaluate"
    _, _ -> "run_code"
  }
}

fn text_content(text: String) -> Json {
  json.object([#("type", json.string("text")), #("text", json.string(text))])
}

fn method_not_found() -> Json {
  json.object([
    #("jsonrpc", json.string("2.0")),
    #(
      "error",
      json.object([
        #("code", json.int(-32_601)),
        #("message", json.string("method not found")),
      ]),
    ),
  ])
}
