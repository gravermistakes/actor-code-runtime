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

/// Run untrusted code inside a supervised, resource-capped BEAM actor.
///
/// NOTE (Phase 2 — scaffold): the real implementation spawns a process with
/// `spawn_opt`/`max_heap_size`, a wall-clock timeout, and a restricted
/// environment, then collects stdout/stderr. This stub exercises the contract
/// and types without yet executing anything. Tracked in docs/ROADMAP.md Phase 2.
pub fn run(_code: String, _limits: Limits) -> ExecResult {
  ExecResult(
    verdict: Errored,
    stdout: "",
    stderr: "actor-code-runtime: execution not yet implemented (Phase 2 scaffold)",
    exit_code: -1,
    duration_ms: 0,
  )
}

pub fn summary(result: ExecResult) -> String {
  verdict_to_string(result.verdict)
  <> " (exit "
  <> int.to_string(result.exit_code)
  <> ")"
}
