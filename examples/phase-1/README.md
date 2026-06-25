# Phase 1 — the thesis, runnable

This directory **is** the proof that Shoggoth Foundry is one architecture and not ten unrelated
repos: wiring the `ruv-swarm` neural swarm into the `Archon` orchestrator takes **one config
file and zero code changes**.

## Files

- [`mcp.json`](mcp.json) — declares the `ruv-swarm` MCP server (`npx ruv-swarm mcp start`).
- [`factory.workflow.yaml`](factory.workflow.yaml) — an Archon workflow whose first node sets
  `mcp: ./mcp.json` and calls the swarm's tools.

Both are **config only**. There is no new runtime code here, which is the point — the example
cannot rot into fiction, because it runs against existing Archon + ruv-swarm exactly as shipped.

## How it works

1. Archon's DAG-node schema has an optional `mcp:` field
   (`Archon/packages/workflows/src/schemas/dag-node.ts:146`).
2. At execution, `loadMcpConfig` (`Archon/packages/providers/src/claude/provider.ts:408-415`)
   reads `mcp.json`, sets `options.mcpServers`, and auto-grants the node `mcp__ruv-swarm__*`
   tools.
3. The node's agent can now call ~18 swarm tools (`agent_spawn`, `task_orchestrate`, `neural_*`,
   `benchmark_run`, …) — neural coordination, through the orchestrator, over MCP.

Every later roadmap phase repeats this exact pattern with a different MCP server (the actor
runtime, MoMoA debate, evolutionary search, AgentDB memory).

## Run it

Prerequisites: `ruv-swarm` available via `npx`, and Archon checked out with Claude configured.

```bash
# Verify the swarm's MCP server launches and lists its tools (standalone sanity check)
npx ruv-swarm mcp start   # Ctrl-C to stop once it reports ready

# From this directory, run the workflow through Archon's CLI
cd examples/phase-1
bun run cli workflow run factory --cwd . "smoke test the swarm bridge"
```

Expected: the `bridge` node returns a summary of the swarm's agent types/capabilities, and the
`assert` node prints `PASS: ruv-swarm MCP bridge responded through Archon`.

> Note: use a non-haiku model (the workflow pins `sonnet`) — MCP tool-search is unsupported on
> haiku.
