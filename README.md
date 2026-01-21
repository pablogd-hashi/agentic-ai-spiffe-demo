# Agentic AI SPIFFE Demo

AI agents communicating over mTLS with SPIFFE identities and Consul intentions. No API keys, no network policies—identity and authorization handled at the sidecar layer.

## Components

- **planner-agent** — receives user requests, forwards to executor
- **executor-agent** — calls the LLM
- **ollama** — local inference (tinyllama)
- **Vault** — PKI and certificate authority
- **Consul** — service mesh, intentions, certificate distribution

Each agent has an Envoy sidecar that handles mTLS and enforces authorization. Apps talk plain HTTP to localhost; sidecars do the rest.

```
User → planner-agent → executor-agent → ollama
            ↓               ↓              ↓
        [sidecar]       [sidecar]      [sidecar]
            └── mTLS ──────┴── mTLS ───────┘
```

See [docs/architecture.md](docs/architecture.md) for the full breakdown.

## Prerequisites

- Docker
- [Task](https://taskfile.dev)

## Quick Start

```bash
task up
```

First run pulls the model (~600MB) and configures Vault/Consul. Subsequent starts are faster.

```bash
task demo
```

Walks through the setup: CA configuration, SPIFFE IDs, default deny, creating/removing intentions.

```bash
task chat
```

Interactive chat through the agent chain.

## Commands

| Command | What it does |
|---------|--------------|
| `task up` | Start everything |
| `task down` | Stop everything |
| `task demo` | Guided walkthrough |
| `task chat` | Chat interface |
| `task allow` | Create intentions |
| `task deny` | Remove intentions |
| `task logs` | Follow logs |

## URLs

| Service | URL |
|---------|-----|
| Vault | http://localhost:8200 (token: `root`) |
| Consul | http://localhost:8500 |
| Planner | http://localhost:8080 |

## Notes

- Model runs on CPU. Keep prompts short.
- The `nomad/` directory has a production-style setup with proper sidecar injection (requires Linux).
