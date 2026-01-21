# Agentic AI SPIFFE Demo

AI agents communicating over mTLS, authenticated via SPIFFE identities and authorized by Consul intentions.

```
User → planner-agent → executor-agent → ollama
            ↓               ↓              ↓
        [sidecar]       [sidecar]      [sidecar]
            └───── mTLS ─────┴───── mTLS ─────┘
```

For detailed architecture, see [docs/architecture.md](docs/architecture.md).

## Prerequisites

- [Docker](https://docs.docker.com/get-docker/)
- [Task](https://taskfile.dev)

## Step 1: Start the Stack

Start Vault, Consul, the agents, and their sidecars:

```bash
task up
```

This will:
- Configure Vault's PKI (root + intermediate CA)
- Wire Consul to Vault as its CA
- Pull the `tinyllama` model (~600MB, first run only)
- Warm the model with a test request

## Step 2: Run the Demo Walkthrough

Run the guided demo to see SPIFFE and intentions in action:

```bash
task demo
```

The walkthrough covers:
- Vault CA setup and SPIFFE IDs in certificates
- Default deny behavior (no intentions = no traffic)
- Creating intentions to allow traffic
- Removing intentions to block traffic

Open Consul UI at http://localhost:8500 while running to watch services register and intentions change.

## Step 3: Chat with the Agents

Once intentions are configured, start an interactive chat:

```bash
task chat
```

Requests flow through `planner → executor → ollama` with mTLS at each hop.

## Available Commands

| Command | Description |
|---------|-------------|
| `task up` | Start all services |
| `task down` | Stop all services |
| `task demo` | Run guided walkthrough |
| `task chat` | Interactive chat |
| `task allow` | Create intentions (allow traffic) |
| `task deny` | Delete intentions (block traffic) |
| `task logs` | Tail all container logs |

## Service URLs

| Service | URL | Notes |
|---------|-----|-------|
| Vault | http://localhost:8200 | Token: `root` |
| Consul | http://localhost:8500 | |
| Planner API | http://localhost:8080 | |

## Notes

- **Performance**: Model runs on CPU. Keep prompts short.
- **Nomad**: The `nomad/` directory contains a production-style setup with proper sidecar injection (requires Linux).
