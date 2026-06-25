import actor_code_runtime/json
import actor_code_runtime/mcp
import actor_code_runtime/runtime
import actor_code_runtime/tools
import gleam/list
import gleam/string
import gleeunit
import gleeunit/should

pub fn main() {
  gleeunit.main()
}

pub fn tool_name_round_trip_test() {
  tools.from_name("run_code") |> should.equal(Ok(tools.RunCode))
  tools.from_name("run_tests") |> should.equal(Ok(tools.RunTests))
  tools.from_name("evaluate") |> should.equal(Ok(tools.Evaluate))
}

pub fn unknown_tool_is_error_test() {
  tools.from_name("nope") |> should.be_error
}

pub fn all_three_tools_listed_test() {
  tools.all() |> list.length |> should.equal(3)
}

pub fn runtime_stub_reports_errored_test() {
  let result = runtime.run("", runtime.default_limits())
  result.verdict |> should.equal(runtime.Errored)
  runtime.is_error(result) |> should.be_true
}

pub fn default_limits_are_capped_test() {
  let limits = runtime.default_limits()
  { limits.wall_clock_ms > 0 } |> should.be_true
  { limits.max_heap_words > 0 } |> should.be_true
}

pub fn initialize_reports_server_name_test() {
  mcp.handle("{\"method\":\"initialize\"}")
  |> string.contains(mcp.server_name)
  |> should.be_true
}

pub fn list_tools_includes_run_code_test() {
  mcp.handle("{\"method\":\"tools/list\"}")
  |> string.contains("run_code")
  |> should.be_true
}

pub fn call_tool_is_flagged_error_while_stubbed_test() {
  mcp.handle("{\"method\":\"tools/call\",\"params\":{\"name\":\"run_code\"}}")
  |> string.contains("\"isError\":true")
  |> should.be_true
}

pub fn json_escapes_quotes_and_newlines_test() {
  json.object([#("k", json.string("a\"b\nc"))])
  |> json.to_string
  |> should.equal("{\"k\":\"a\\\"b\\nc\"}")
}

pub fn json_encodes_array_and_bool_test() {
  json.array([1, 2, 3], json.int)
  |> json.to_string
  |> should.equal("[1,2,3]")

  json.bool(True) |> json.to_string |> should.equal("true")
}
