# Specification

This is the core document. It defines the architecture, the connective tissue, the contract
of each layer, and how the four orchestrators differ. Diagrams live in
[`ARCHITECTURE.md`](ARCHITECTURE.md); the phased plan lives in [`ROADMAP.md`](ROADMAP.md).

## 1. Connective tissue

The system coheres around three shared mechanisms. Every integration in the roadmap is an
instance of one of them.

### 1.1 MCP — the universal agent↔capability bus

The [Model Context Protocol](https://modelcontextprotocol.io) is the spine. A capability
(neural inference, code execution, debate, memory, infra action) is exposed as an **MCP
server**; an orchestrator consumes it as an **MCP client**. This is already wired in the
keystone repos:

- **Producer:** `ruv-swarm` ships a stdio MCP server (`npx ruv-swarm mcp start`) exposing ~18
  tools (`agent_spawn`, `task_orchestrate`, `neural_*`, `benchmark_run`, …). There is also a
  Rust crate at `ruv-FANN/ruv-swarm/crates/ruv-swarm-mcp`.
- **Consumer:** Archon DAG nodes have an optional `mcp:` field
  (`packages/workflows/src/schemas/dag-node.ts:146`). At execution, `loadMcpConfig`
  (`packages/providers/src/claude/provider.ts:408-415`) reads the JSON, sets `mcpServers`, and
  auto-grants `mcp__<name>__*` tools to that node.

**Consequence:** integrating two layers usually means authoring one config file, not changing
code. New capabilities (the actor runtime, MoMoA debate, evolutionary search, RAG memory)
are each adopted by wrapping them as one more MCP server.

### 1.2 WASM — the portable compute format

Neural inference compiles to WebAssembly so the same artifact runs in a browser, on a server,
inside the actor runtime, or on Android. `ruv-fann-neural-bridge` is the canonical WASM
inference target; `microui` compiles to WASM via sokol. WASM is one of two isolation mechanisms
for the execution substrate (DECISIONS D2); the other is **BEAM process isolation** (see §1.4).

### 1.3 Self-hostability — the constraint

Every layer must have a fully self-hosted deployment with no required third-party SaaS in the
critical path. This is a hard architectural constraint, not a preference: it is what the whole
project is *for*. A component that can only run against a hosted API does not belong in a
critical layer (it may be an optional accelerator).

### 1.4 BEAM actor isolation — the execution model

Beyond the three connective tissues above, the convergence language **Gleam** on the BEAM
(Erlang VM) gives the factory its execution model: every untrusted code run is a lightweight,
**memory-isolated, preemptively scheduled process** under an OTP **supervision tree**, with
per-process resource caps (`max_heap_size`, reduction budgets) and "let it crash" recovery. This
is why `actor-code-runtime` can run agent-generated code safely without a heavyweight container
per run. See [DECISIONS D4](DECISIONS.md#d4--gleam-is-the-convergence-language). Numeric kernels
that must be fast (neural ops) stay in Rust/WASM and are invoked from Gleam over ports/NIFs.

## 2. Layer contracts

Each layer is defined by what it **consumes** and what it **exposes**. The target interface for
inter-layer communication is always MCP.

| Layer | Repo(s) | Exposes | Consumes |
|-------|---------|---------|----------|
| Compute | `ruv-FANN` / `ruv-swarm` | MCP server (~18 tools): swarm spawn, orchestrate, neural ops | — |
| Compute (edge) | `ruv-fann-neural-bridge` | WASM inference module (JS/Rust bindings) | ruv-FANN models |
| Orchestration (det.) | `Archon` | Workflow runs; meta-orchestrator | MCP servers (all others) |
| Orchestration (adv.) | `MoMoA` | MCP server: `debate` | LLM backends; an MCP client |
| Orchestration (evo.) | `advanced_evolution` | MCP server: `search` / `evolve` | execution substrate (fitness); LLM |
| Orchestration (HITL) | `eidolon-reference` | MCP server: `plan` / `approve`; audit log | infra; human approval |
| Glue + memory | `n8n-android-kit` | MCP server: `memory.*` (AgentDB / Qdrant); event triggers | AgentDB/Qdrant, Ollama, webhooks |
| Execution | `actor-code-runtime` | MCP server: `run_code` / `run_tests` / `evaluate` | code candidates (git diffs) |
| Fabric | `headscale` | Private mesh addressing + ACLs | node registrations |
| UI | `microui` | Rendered control surface (native/WASM) | factory state (read), approvals (write) |

## 3. The four orchestrators

The single most-scrutinized design claim is that four orchestration repos are not redundant.
They occupy four distinct points on a **(determinism × reversibility × search-breadth)** cube:

| Orchestrator | Mode | Mental model | Use when |
|--------------|------|--------------|----------|
| **Archon** | Deterministic | One principled pass through an explicit DAG | the path is known |
| **MoMoA** | Adversarial | One answer, stress-tested by conflicting expert personas debating | the answer is contested/ambiguous |
| **advanced_evolution** | Evolutionary | Many candidate solutions, evaluated and selected over generations | you can score outcomes but can't specify the path |
| **eidolon** | Human-gated | Plan → human approves → execute, with audit trail | actions are irreversible/operational |

> **Archon decides the path, MoMoA argues the answer, evolution searches the space, eidolon
> asks permission.**

**Archon is the meta-orchestrator** (DECISIONS D3). A normal task runs as an Archon DAG. When a
single node is high-uncertainty, Archon delegates that sub-step to MoMoA (debate) or
advanced_evolution (search) via MCP; when a step has irreversible side-effects, it routes
through eidolon's approval gate. The other three are tools Archon reaches for, not competing
front doors.

### Boundary note: Archon vs n8n

Both can "orchestrate." The boundary: **Archon orchestrates *agent reasoning steps* inside one
software-change task; n8n orchestrates *events between systems* (triggers, schedules, connectors)
that start or react to Archon runs.** n8n fires the gun; Archon runs the race. Shared
infrastructure (RAG memory) lives on the n8n side.

## 4. The execution-substrate boundary

Several repos can "run code in isolation." To avoid two layers doing the same job, the boundary
is defined precisely (full decision in [DECISIONS D2](DECISIONS.md#d2--the-execution-substrate-boundary)):

- **Archon worktrees** — isolation for *agent file edits* (git-level, trusted-ish, the normal case).
- **actor-code-runtime** — isolation for *executing the code agents generated* (untrusted runs:
  test suites, evolutionary fitness evaluation, generated scripts). Each execution is a
  supervised, message-passing, resource-capped **actor**. This is the substrate Archon's
  `validate` node and advanced_evolution's evaluator both call.
- **eidolon sandbox** — isolation for *operating on real infrastructure* with human approval
  (a different threat model: side-effects on prod, not code correctness).

This is what gives `actor-code-runtime` a genuine reason to exist beyond hosting these docs.

## 5. End-to-end request lifecycle

1. A trigger (CLI, chat, webhook via n8n, or cron) hands a goal to **Archon**.
2. Archon plans a DAG. For each node it picks an execution mode; hard nodes delegate to
   **MoMoA** / **advanced_evolution** over MCP; side-effecting nodes route through **eidolon**.
3. Agents draft changes inside an Archon git **worktree**, calling **ruv-swarm** MCP tools for
   neural coordination and **AgentDB** memory tools for relevant past context.
4. The `validate` node submits the candidate to **actor-code-runtime**, which runs tests in an
   isolated actor and returns a verdict / fitness score.
5. advanced_evolution may spawn N such candidates and select the best.
6. Results and learnings are written back to **AgentDB** memory.
7. A human sees state and approves irreversible steps through the **microui** console; runners
   on different hosts reach each other over the **headscale** mesh.

## 6. Security model (summary)

- **Untrusted by default.** Code produced by agents is untrusted; it only ever executes inside
  actor-code-runtime with resource caps (CPU, memory, wall-clock, filesystem, network).
- **Side-effects are gated.** Anything that touches real infrastructure goes through eidolon's
  human-approval + audit trail.
- **Least privilege over the mesh.** headscale ACLs gate which agent/runner can reach which MCP
  server.
- **Secrets never in git.** Per-project secrets are injected at execution time (Archon already
  does this for env vars); they are never committed.
