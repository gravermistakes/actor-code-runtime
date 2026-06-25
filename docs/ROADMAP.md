# Roadmap

From ten disconnected repos to one integrated factory. Five phases, ordered by **leverage ÷
effort**. Every phase reuses the same "wrap-as-MCP-server" pattern — which is why the
architecture is credible rather than aspirational.

Status legend: ☐ not started · ◐ in progress · ☑ done

---

## Phase 1 — Prove the MCP bus: Archon ↔ ruv-swarm  ☐

- **Repos:** Archon, ruv-FANN / ruv-swarm.
- **Seam (concrete):** Author `mcp.json`:
  `{"ruv-swarm": {"command": "npx", "args": ["ruv-swarm", "mcp", "start"]}}`. Add
  `mcp: "./mcp.json"` to one node in an Archon workflow YAML (schema:
  `packages/workflows/src/schemas/dag-node.ts:146`). Archon's `loadMcpConfig`
  (`packages/providers/src/claude/provider.ts:408`) auto-exposes `mcp__ruv-swarm__*` tools.
- **Effort:** ~1 day. Config + one demo workflow + verifying the tools surface.
- **Unlocks:** Archon agents spawn/orchestrate swarm agents and run neural ops *through MCP*.
  Proves the central thesis with near-zero code. **This is the demo that validates the project.**
- **Artifacts here today:** [`examples/phase-1/`](../examples/phase-1/) — `mcp.json`,
  `factory.workflow.yaml`, and a walkthrough in its
  [`README`](../examples/phase-1/README.md).

## Phase 2 — Give the factory a body: actor-code-runtime as the untrusted executor  ◐

- **Repos:** actor-code-runtime, Archon (`validate` node), advanced_evolution.
- **Seam:** Define actor-code-runtime's contract as an **MCP server** with tools `run_code`,
  `run_tests`, `evaluate`, so Archon's `validate` step and the evolver call it identically.
  Ratify the boundary in [DECISIONS D2](DECISIONS.md#d2--the-execution-substrate-boundary).
  advanced_evolution's `GitBasedOrganism.build_repo()` → submit candidate → receive fitness.
- **Effort:** Medium — this is where the first real new code lives (the runtime engine, in Gleam
  per [DECISIONS D4](DECISIONS.md#d4--gleam-is-the-convergence-language)).
- **Done so far:** A compiling, tested Gleam MCP server — `src/actor_code_runtime/`
  (`json`, `tools`, `runtime`, `mcp`) + a stdio entry point and Erlang FFI. `gleam test` passes
  and the server answers `initialize` / `tools/list` / `tools/call` over JSON-RPC. **`runtime.run/2`
  now really executes code** as an OS subprocess under `/bin/sh -c` with a hard wall-clock
  deadline, capturing combined output + exit status and mapping it to a verdict
  (`passed`/`failed`/`timed_out`); tests cover all three.
- **Next increments:** (1) decode JSON-RPC request params (`id`, `code`/`command`/`diff`) and feed
  them into `runtime.run`; (2) stronger per-run isolation — cgroups/seccomp/container and BEAM
  `max_heap_size` for in-VM evaluation; (3) wire Archon's `validate` node + advanced_evolution's
  evaluator to call this server.
- **Unlocks:** Safe execution of generated/candidate code; the substrate that makes evolution +
  validation trustworthy.

## Phase 3 — Add the other brains: Archon invokes MoMoA + advanced_evolution  ☐

- **Repos:** Archon, MoMoA, advanced_evolution.
- **Seam:** Wrap MoMoA (express/WebSocket + ACP) and the evolver as **MCP servers**
  (`momoa__debate`, `evolution__search`), consumed by Archon nodes exactly like Phase 1. Archon
  becomes the meta-orchestrator ([DECISIONS D3](DECISIONS.md#d3--archon-is-the-meta-orchestrator)): a node
  delegates a hard sub-decision to debate, or a hard sub-search to evolution.
- **Effort:** Medium-high — thin MCP shims over existing programmatic entrypoints.
- **Unlocks:** The four-orchestrator cube operational. The factory picks the right reasoning
  mode per step.

## Phase 4 — Memory + edge inference: n8n/Qdrant RAG + neural-bridge WASM  ☐

- **Repos:** n8n-android-kit, ruv-fann-neural-bridge, ruv-FANN.
- **Seam:** Stand up the compose stack; expose Qdrant as a shared-memory MCP server
  (`memory.search` / `memory.store`) so all orchestrators read/write the same RAG store. Adopt
  neural-bridge as the **WASM inference target** for ruv-FANN models, re-homing its `Cargo.toml`
  `repository` field off `ruvnet/claude-flow` to Shoggoth Foundry. n8n triggers (webhook/cron)
  kick off Archon runs.
- **Effort:** Medium — compose is ready; the MCP memory shim + neural-bridge adoption are the work.
- **Unlocks:** Persistent cross-run memory; portable inference (browser/Android/actor);
  event-driven factory runs.

## Phase 5 — Scale-out + steer: headscale mesh + eidolon HITL + microui console  ☐

- **Repos:** headscale, eidolon-reference, microui.
- **Seam:** headscale mesh so runners/MCP servers on different hosts address each other
  privately (ACLs gate which agent reaches which tool). eidolon becomes the **approval/audit
  gate** in front of any side-effecting action (its `SandboxRuntime` + audit trail + Neo4j
  graph). microui (sokol/WASM) ships as the minimal approval/dashboard console.
- **Effort:** High, but each piece is independently optional.
- **Unlocks:** Multi-host scale, human governance, a portable control surface. "v1 complete."

---

## Sequencing logic

MCP bus first (cheapest proof) → execution body → more brains → memory/edge → scale/governance.
Honest notes on the weak fits, surfaced rather than hidden:

- **headscale** is justified only once the factory spans more than one host — hence Phase 5,
  not the core. It is *wrapped*, never rewritten.
- **microui** is the deliberately austere, constrained-environment UI (Android, embedded,
  offline) — chosen over a heavier React stack to honor the self-host/no-bloat ethos. It is the
  last mile and remains opt-in.

## Convergence track (parallel, long-horizon)

Independent of the feature phases, [DECISIONS D4](DECISIONS.md#d4--gleam-is-the-convergence-language)
defines **wrap-then-converge** toward Gleam: every new component (starting with actor-code-runtime
in Phase 2) is written in Gleam; existing non-Gleam repos are wrapped as MCP servers now and
rewritten only where a rewrite pays for itself. There is no big-bang rewrite milestone.
