# Agentic AI SPIFFE Demo

A working demo of cryptographic identity for AI agents using Vault and Consul.

## What this demo shows

- Vault issuing SPIFFE certificates via PKI engine
- Consul using Vault as its Certificate Authority
- mTLS enforced by Envoy sidecars between all services
- Intentions controlling which agents can talk to which
- Traffic flow: planner-agent → executor-agent → ollama

For details on how each component works, see [docs/architecture.md](docs/architecture.md).

## Requirements

- Docker and Docker Compose
- [Task](https://taskfile.dev) (Taskfile runner)

## Running the demo

Start all services:

```bash
task up
```

This starts Vault, Consul, Ollama, and both agents. It also pulls the Ollama model.

Run the guided demo:

```bash
task demo
```

The demo walks through SPIFFE certificates, mTLS, and intentions step by step. It pauses between steps so you can inspect the state in Consul UI. These pauses are intentional for live demos.

## Main tasks

| Task | Description |
|------|-------------|
| `task up` | Start all services |
| `task down` | Stop all services |
| `task demo` | Guided walkthrough with pauses |
| `task chat` | Interactive chat with the AI |
| `task intentions:create` | Allow traffic between agents |
| `task intentions:delete` | Block traffic (default deny) |
| `task test:deny` | Test that traffic is blocked |
| `task test:allow` | Test that traffic is allowed |
| `task status` | Show service status |
| `task --list` | Show all available tasks |

## Access URLs

| Service | URL | Notes |
|---------|-----|-------|
| Vault | http://localhost:8200 | Token: `root` |
| Consul | http://localhost:8500 | |
| Planner | http://localhost:8080 | Entry point for questions |

## What this demo is NOT

- Not production-ready (dev mode, no HA, no persistent storage)
- Not covering GPU acceleration or scaling
- Not teaching LLM prompting or agent design

The agents are simple Flask apps. They exist to show identity and authorization, not AI capabilities.
