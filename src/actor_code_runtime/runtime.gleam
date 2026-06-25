//// The execution model: untrusted code runs inside a supervised, resource-capped
//// BEAM actor (see docs/DECISIONS.md D4). This module defines the contract and
//// result types. The actual process spawn is a documented Phase-2 stub for now.

import gleam/int

pub type Verdict {
  Passed
  Failed
  TimedOut
  Errored
}

pub fn verdict_to_string(verdict: Verdict) -> String {
  case verdict {
    Passed -> "passed"
    Failed -> "failed"
    TimedOut -> "timed_out"
    Errored -> "errored"
  }
}

/// Per-run resource caps enforced on the spawned actor.
pub type Limits {
  Limits(wall_clock_ms: Int, max_heap_words: Int)
}

pub fn default_limits() -> Limits {
  Limits(wall_clock_ms: 30_000, max_heap_words: 50_000_000)
}

pub type ExecResult {
  ExecResult(
    verdict: Verdict,
    stdout: String,
    stderr: String,
    exit_code: Int,
    duration_ms: Int,
  )
}

pub fn is_error(result: ExecResult) -> Bool {
  case result.verdict {
    Errored -> True
    _ -> False
  }
}

@external(erlang, "acr_ffi", "run_command")
fn run_command(
  command: String,
  timeout_ms: Int,
) -> Result(#(Int, String, Int), Int)

/// Run untrusted code as an OS subprocess under `/bin/sh -c`, bounded by a hard
/// wall-clock deadline (`limits.wall_clock_ms`). Combined stdout+stderr is
/// captured and the exit status is mapped to a `Verdict`.
///
/// Isolation today is the timeout-bounded subprocess. Stronger per-run
/// sandboxing (cgroups / seccomp / container, plus BEAM `max_heap_size` for
/// in-VM evaluation) is tracked in docs/ROADMAP.md Phase 2.
pub fn run(code: String, limits: Limits) -> ExecResult {
  case run_command(code, limits.wall_clock_ms) {
    Ok(#(exit_code, output, duration_ms)) ->
      ExecResult(
        verdict: case exit_code {
          0 -> Passed
          _ -> Failed
        },
        stdout: output,
        stderr: "",
        exit_code: exit_code,
        duration_ms: duration_ms,
      )
    Error(duration_ms) ->
      ExecResult(
        verdict: TimedOut,
        stdout: "",
        stderr: "wall-clock timeout exceeded ("
          <> int.to_string(limits.wall_clock_ms)
          <> "ms)",
        exit_code: -1,
        duration_ms: duration_ms,
      )
  }
}

pub fn summary(result: ExecResult) -> String {
  verdict_to_string(result.verdict)
  <> " (exit "
  <> int.to_string(result.exit_code)
  <> ")"
}
