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

pub fn runtime_runs_command_and_captures_stdout_test() {
  let result = runtime.run("echo hello", runtime.default_limits())
  result.verdict |> should.equal(runtime.Passed)
  result.exit_code |> should.equal(0)
  result.stdout |> string.contains("hello") |> should.be_true
}

pub fn runtime_maps_nonzero_exit_to_failed_test() {
  let result = runtime.run("exit 3", runtime.default_limits())
  result.verdict |> should.equal(runtime.Failed)
  result.exit_code |> should.equal(3)
}

pub fn runtime_enforces_wall_clock_timeout_test() {
  let result =
    runtime.run(
      "sleep 5",
      runtime.Limits(wall_clock_ms: 150, max_heap_words: 1),
    )
  result.verdict |> should.equal(runtime.TimedOut)
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

pub fn call_tool_acknowledges_tool_test() {
  let out =
    mcp.handle("{\"method\":\"tools/call\",\"params\":{\"name\":\"run_code\"}}")
  out |> string.contains("run_code") |> should.be_true
  out |> string.contains("\"isError\":false") |> should.be_true
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
