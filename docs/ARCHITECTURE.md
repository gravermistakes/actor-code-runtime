# Architecture

Diagrams for the structures described in [`SPEC.md`](SPEC.md). All diagrams are Mermaid.

## Layer stack

```mermaid
flowchart TB
    subgraph UI["UI"]
        microui["microui — zero-dep console (native/WASM)"]
    end
    subgraph ORCH["Orchestration brains"]
        archon["Archon — deterministic / meta-orchestrator"]
        momoa["MoMoA — adversarial debate"]
        evo["advanced_evolution — evolutionary search"]
        eidolon["eidolon — human-gated ops"]
    end
    subgraph GLUE["Glue + memory"]
        n8n["n8n — triggers / connectors"]
        qdrant["AgentDB / Qdrant — RAG memory"]
        ollama["Ollama — local LLM"]
    end
    subgraph EXEC["Execution substrate"]
        acr["actor-code-runtime — untrusted code execution"]
    end
    subgraph COMPUTE["Neural compute"]
        ruvfann["ruv-FANN / ruv-swarm — nets + swarm (MCP)"]
        bridge["ruv-fann-neural-bridge — WASM inference"]
    end
    subgraph FABRIC["Networking fabric"]
        headscale["headscale — private mesh + ACLs"]
    end

    microui --> archon
    archon --> momoa & evo & eidolon
    archon --> acr
    archon --> qdrant
    archon --> ruvfann
    n8n --> archon
    n8n --- qdrant & ollama
    evo --> acr
    ruvfann --- bridge
    FABRIC -. connects every node .- ORCH
    FABRIC -. connects every node .- EXEC
    FABRIC -. connects every node .- COMPUTE
```

## The MCP bus

Every cross-layer call is an MCP client→server hop. Archon is the primary client.

```mermaid
flowchart LR
    archon(["Archon (MCP client)"])
    subgraph servers["MCP servers"]
        s1["ruv-swarm\nagent_spawn, neural_*"]
        s2["actor-code-runtime\nrun_code, run_tests, evaluate"]
        s3["MoMoA\ndebate"]
        s4["advanced_evolution\nsearch / evolve"]
        s5["n8n / AgentDB\nmemory.search, memory.store"]
        s6["eidolon\nplan, approve"]
    end
    archon -->|mcp.json| s1
    archon --> s2
    archon --> s3
    archon --> s4
    archon --> s5
    archon --> s6
```

The Phase-1 edge (`Archon → ruv-swarm`) is live today with **one JSON file**. The rest of the
roadmap repeats this exact pattern.

## Request lifecycle

```mermaid
sequenceDiagram
    participant Trigger as Trigger (CLI/chat/n8n/cron)
    participant Archon
    participant Brain as MoMoA / evolution / eidolon
    participant Swarm as ruv-swarm (MCP)
    participant Mem as AgentDB memory (MCP)
    participant Runtime as actor-code-runtime (MCP)
    participant Human

    Trigger->>Archon: goal
    Archon->>Archon: plan DAG, open worktree
    Archon->>Mem: memory.search(context)
    loop per node
        alt high-uncertainty node
            Archon->>Brain: delegate (debate / search / plan)
            Brain-->>Archon: result
        end
        Archon->>Swarm: neural coordination tools
        Archon->>Runtime: run_tests(candidate diff)
        Runtime-->>Archon: verdict / fitness
    end
    Archon->>Human: request approval (irreversible steps)
    Human-->>Archon: approve / reject (via microui + eidolon)
    Archon->>Mem: memory.store(learnings)
    Archon-->>Trigger: reviewed code (PR)
```

## Execution-substrate boundary

Three isolations, three threat models (see [DECISIONS D2](DECISIONS.md#d2--the-execution-substrate-boundary)):

```mermaid
flowchart TB
    subgraph edits["Agent file edits — trusted-ish"]
        wt["Archon git worktrees"]
    end
    subgraph run["Run generated code — UNtrusted"]
        acr["actor-code-runtime\nresource-capped BEAM actors (Gleam/OTP)"]
    end
    subgraph infra["Operate on real infra — side-effecting"]
        sb["eidolon SandboxRuntime\n+ human approval + audit"]
    end
    edits -->|"candidate diff"| run
    run -->|"verdict"| edits
    edits -->|"irreversible action"| infra
```
