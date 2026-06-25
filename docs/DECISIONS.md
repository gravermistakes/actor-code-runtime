# Decisions

The load-bearing architectural decisions, recorded compactly. One section each: context →
decision → consequences. (Consolidated in the spirit of minimalism — one file, not one per
decision.)

---

## D1 — MCP is the universal agent↔capability bus

**Context.** Ten repos in five languages with no existing cross-references. We need one
integration mechanism, not N×M adapters. Two facts make the choice automatic: `ruv-swarm` already
ships an MCP server (`npx ruv-swarm mcp start`, ~18 tools; Rust crate at
`ruv-FANN/ruv-swarm/crates/ruv-swarm-mcp`), and Archon already *consumes* MCP per node (`mcp:`
field at `packages/workflows/src/schemas/dag-node.ts:146`, wired by `loadMcpConfig` at
`packages/providers/src/claude/provider.ts:408-415`).

**Decision.** Every capability (compute, execution, debate, search, memory, infra action) is
exposed as an MCP server; orchestrators consume it as an MCP client. Language is irrelevant at the
boundary.

**Consequences.** Integration cost collapses to "one MCP server + one config entry." Polyglot
repos interoperate with no shared runtime. Cost: a process boundary per call — fine for
orchestration-grade calls, not hot loops; hot numeric paths stay in-process (Rust/WASM), not MCP.

---

## D2 — The execution-substrate boundary

**Context.** Several repos can "run code in isolation" (Archon worktrees, eidolon's
`SandboxRuntime` at `eidolon-reference/eidolon/runtime/sandbox.py`, MoMoA's e2b). Without a clear
line, the architecture looks like two layers doing one job.

**Decision.** Three isolations, three threat models:
- **Archon worktrees** — isolation for *agent file edits* (git-level, trusted-ish, normal case).
- **actor-code-runtime** — isolation for *executing the code agents generated* (untrusted runs:
  test suites, evolutionary fitness eval, generated scripts). Each run is a supervised,
  resource-capped BEAM actor. Shared by Archon's `validate` node and advanced_evolution's
  evaluator (`advanced_evolution/darwinian_evolver/git_based_problem.py` `GitBasedOrganism`).
- **eidolon sandbox** — isolation for *operating on real infrastructure* with human approval
  (side-effects, not code correctness).

**Consequences.** This is what gives `actor-code-runtime` a genuine reason to exist beyond hosting
docs. It is the first real new code (Phase 2).

---

## D3 — Archon is the meta-orchestrator

**Context.** Four orchestration repos risk looking redundant. They occupy four points on a
(determinism × reversibility × search-breadth) cube: Archon (deterministic), MoMoA (adversarial),
advanced_evolution (evolutionary), eidolon (human-gated).

**Decision.** A normal task runs as an Archon DAG. High-uncertainty nodes are delegated to MoMoA
(debate) or advanced_evolution (search) over MCP; side-effecting nodes route through eidolon's
approval gate. The other three are tools Archon reaches for, not competing front doors.

**Consequences.** One front door, four reasoning modes. n8n stays distinct: it orchestrates
*events between systems* that start/react to Archon runs; Archon orchestrates *reasoning steps*
inside one task.

---

## D4 — Gleam is the convergence language

**Context.** The owner's constraint: pick a deliberately *underused* language for the unified
project. The factory's home layer is an actor runtime that must execute untrusted code safely.

**Decision.** Converge on **Gleam** (statically-typed, on the BEAM). Rationale: the BEAM is the
canonical actor-model platform — memory-isolated processes, OTP supervision trees, per-process
resource caps (`max_heap_size`, reduction budgets), "let it crash" recovery — which *is* the
execution model `actor-code-runtime` needs, without a container per run. Gleam also compiles to
JavaScript (portability parallel to WASM). Numeric/neural kernels stay Rust→WASM, called from
Gleam over ports/NIFs.

**Strategy: wrap-then-converge.** New components are written in Gleam (starting with this runtime
in Phase 2). Existing non-Gleam repos are wrapped as MCP servers now and rewritten only where a
rewrite pays for itself. There is **no big-bang rewrite** of mature systems (e.g. headscale).

**Consequences.** Execution safety and concurrency are first-class. Trade-off: a smaller library
ecosystem than mainstream languages — mitigated because heavy lifting (numerics, existing repos)
is reached over MCP/ports, not reimplemented.

---

## D5 — AgentDB is the recommended memory backend

**Context.** The factory needs durable cross-run RAG memory. The n8n kit bundles Qdrant. AgentDB
(SQLite-based, in-process HNSW vector search, QUIC peer sync) is more aligned with the
self-hosting constraint.

**Decision.** Recommend **AgentDB** as the memory layer, exposed as a `memory.*` MCP server; keep
Qdrant as the n8n-kit's bundled alternative. AgentDB's QUIC sync pairs naturally with the
headscale mesh for multi-host memory replication.

**Consequences.** Memory is in-process and self-hosted with no external vector-DB service
required; embeds cleanly into the BEAM-hosted runtime.
