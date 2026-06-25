//// The MCP tool surface of the execution substrate.
////
//// Three tools, one boundary (see docs/DECISIONS.md D2): all of them run
//// untrusted, agent-generated code inside an isolated, resource-capped actor.

import actor_code_runtime/json.{type Json}

pub type Tool {
  RunCode
  RunTests
  Evaluate
}

pub fn all() -> List(Tool) {
  [RunCode, RunTests, Evaluate]
}

pub fn name(tool: Tool) -> String {
  case tool {
    RunCode -> "run_code"
    RunTests -> "run_tests"
    Evaluate -> "evaluate"
  }
}

pub fn from_name(raw: String) -> Result(Tool, String) {
  case raw {
    "run_code" -> Ok(RunCode)
    "run_tests" -> Ok(RunTests)
    "evaluate" -> Ok(Evaluate)
    other -> Error("unknown tool: " <> other)
  }
}

pub fn description(tool: Tool) -> String {
  case tool {
    RunCode ->
      "Execute a code snippet in an isolated, resource-capped actor and return its output and verdict."
    RunTests ->
      "Run a candidate's test suite in isolation and return pass/fail plus captured output."
    Evaluate ->
      "Run a candidate (a git diff) and return a fitness score for evolutionary search."
  }
}

/// The MCP `tools/list` entry for a tool.
pub fn to_json(tool: Tool) -> Json {
  json.object([
    #("name", json.string(name(tool))),
    #("description", json.string(description(tool))),
    #("inputSchema", input_schema(tool)),
  ])
}

fn input_schema(tool: Tool) -> Json {
  let properties = case tool {
    RunCode -> [
      #("code", string_prop("Source code to execute")),
      #("language", string_prop("Language id, e.g. \"gleam\" or \"bash\"")),
    ]
    RunTests -> [
      #("diff", string_prop("Unified git diff of the candidate")),
      #("command", string_prop("Test command to run")),
    ]
    Evaluate -> [
      #("diff", string_prop("Unified git diff of the candidate")),
      #("fitness_command", string_prop("Command whose result defines fitness")),
    ]
  }
  json.object([
    #("type", json.string("object")),
    #("properties", json.object(properties)),
  ])
}

fn string_prop(desc: String) -> Json {
  json.object([
    #("type", json.string("string")),
    #("description", json.string(desc)),
  ])
}
