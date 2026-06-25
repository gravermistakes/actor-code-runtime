//// Shoggoth Foundry — execution substrate entry point.
////
//// A stdio MCP server: read one JSON-RPC request per line from stdin, write one
//// JSON-RPC response per line to stdout. This is the form Archon's `mcp:` node
//// field consumes (see examples/phase-1 and docs/SPEC.md).

import actor_code_runtime/mcp
import gleam/io

@external(erlang, "acr_ffi", "read_line")
fn read_line() -> Result(String, Nil)

pub fn main() {
  serve()
}

fn serve() -> Nil {
  case read_line() {
    Ok(line) -> {
      io.println(mcp.handle(line))
      serve()
    }
    Error(_) -> Nil
  }
}
