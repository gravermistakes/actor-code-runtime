# Shoggoth Foundry

> A self-hosted, self-improving software factory.

Give it a goal; get back reviewed, working code — with **no cloud lock-in at any layer**.
Shoggoth Foundry is an umbrella architecture that unifies ten existing repositories into one
coherent system: neural compute, four kinds of agent orchestration, durable memory, an isolated
execution runtime, a private mesh network, and a minimal control surface.

This repository (`actor-code-runtime`) is **both** the home of the umbrella documentation **and**
the execution substrate of the factory — the isolated runtime where agent-generated code runs.

## Why this exists

Most "AI agent" systems share two weaknesses: they are **cloud-bound** (you don't own the loop)
and they **don't improve** (each run starts from the same place). The ten repos here, arranged by
layer, fix both: compute, memory, and execution are all self-hosted down to the network; and
evolutionary search makes the factory get better at building by building.

**Non-goals:** not a hosted SaaS, not a model lab (we consume models, local or API; we don't
train foundation models), not a big-bang rewrite, not cloud-*hostile* (self-hostable ≠ can't use
an API — it means never *forced* to).

## The thesis in one fact

Integration is nearly free. An Archon workflow node accepts an optional `mcp:` config path
(`packages/workflows/src/schemas/dag-node.ts:146`). `ruv-swarm` already ships a stdio **MCP**
server (`npx ruv-swarm mcp start`, ~18 tools). So wiring the neural swarm into the orchestrator
is **one JSON file and zero code changes** — see [`examples/phase-1/`](examples/phase-1/). Every
later integration reuses that same "wrap-as-MCP-server" pattern. That is what turns ten
thematically-related repos into one architecture.

## The ten layers

| # | Repo | Layer | Role |
|---|------|-------|------|
| 1 | `ruv-FANN` (+ `ruv-swarm`) | Compute + coordination | Neural substrate; the **first MCP server** every orchestrator consumes |
| 2 | `ruv-fann-neural-bridge` | Compute (edge) | Portable **WASM** inference — runs models in browser / actor / Android |
| 3 | `Archon` | Orchestration: deterministic | Default control plane + **meta-orchestrator** that invokes the other brains |
| 4 | `MoMoA` | Orchestration: adversarial | Debate / peer-review engine for high-uncertainty sub-steps |
| 5 | `advanced_evolution` | Orchestration: evolutionary | Population search over candidate solutions; self-improvement loop |
| 6 | `eidolon-reference` | Orchestration: HITL ops | Human-gated infra actions + the audit / permission spine |
| 7 | `n8n-android-kit-attempt` | Glue + memory | Event triggers + RAG memory (**AgentDB** / Qdrant) + local LLM (Ollama) |
| 8 | `actor-code-runtime` | Execution substrate | Isolated runtime for **untrusted generated code** (tests / fitness eval). **This repo.** |
| 9 | `headscale` | Networking fabric | Private mesh so distributed runners / MCP servers reach each other |
| 10 | `microui` | UI | Minimal, zero-dependency, WASM-compilable approval / dashboard console |

Connective tissue: **MCP** (the universal agent↔capability bus), **WASM** (the portable compute
format), and **self-hostability** (the non-negotiable constraint).

## The four orchestrators, differentiated

> **Archon decides the path, MoMoA argues the answer, evolution searches the space, eidolon asks permission.**

Not four ways to do the same thing — four points on a (determinism × reversibility ×
search-breadth) cube. Archon is the meta-orchestrator that invokes the other three as MCP tools.
Details in [`docs/SPEC.md`](docs/SPEC.md).

## Language: Gleam (deliberately underused)

The convergence language is **Gleam** — a young, statically-typed language on the BEAM (Erlang
VM). This layer is an *actor runtime*, and the BEAM is the canonical actor-model platform:
memory-isolated lightweight processes, OTP supervision trees, per-process resource caps, and
"let it crash" fault isolation — exactly what's needed to run untrusted, agent-generated code
safely. Gleam also compiles to JavaScript for "lands anywhere" portability. Numeric/neural
kernels (ruv-FANN) stay Rust→WASM and are called over ports/NIFs. Strategy is **wrap-then-converge**:
MCP-shim existing repos first, rewrite into Gleam only where it pays. See
[`docs/DECISIONS.md`](docs/DECISIONS.md).

## Principles

- **Self-hosted to the network layer** — nothing required in the critical path is a third-party SaaS.
- **Self-improving** — evolutionary search optimizes both target code and the factory's own prompts.
- **Minimalism gate (ponytail)** — every orchestrator's generated output passes a "lazy senior dev"
  decision ladder (*does this need to exist? reuse? stdlib? one line? only then the minimum that
  works*) before it's accepted. Applied to this repo's own docs, too.

## How it's built (SPARC)

Specification → Pseudocode → Architecture → Refinement → Completion. The docs map onto it:
SPEC = Specification, ARCHITECTURE = Architecture, ROADMAP = Refinement plan. Keep contributions
modular, files small, and no hard-coded secrets.

## Documentation map

- [`docs/SPEC.md`](docs/SPEC.md) — architecture, component contracts, the four orchestrators, connective tissue
- [`docs/ARCHITECTURE.md`](docs/ARCHITECTURE.md) — diagrams: layer stack, MCP bus, request lifecycle, exec boundary
- [`docs/ROADMAP.md`](docs/ROADMAP.md) — the five-phase integration plan
- [`docs/DECISIONS.md`](docs/DECISIONS.md) — the load-bearing decisions (MCP bus, exec boundary, Gleam, memory, meta-orchestrator)
- [`examples/phase-1/`](examples/phase-1/) — the runnable, config-only proof of the thesis

## Status

Thesis + Phase-1 proof. The runtime engine is **not yet built** — this pass is documentation
plus a config-only proof-of-concept. See the roadmap for what comes next.
