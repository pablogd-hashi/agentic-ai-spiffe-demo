# Agentic AI SPIFFE Demo

This repo exists to make one thing visible: how workload identity and authorization actually behave when AI services talk to each other.

Instead of API keys or network trust, services authenticate with SPIFFE identities and communicate over mutual TLS. Authorization is enforced by Consul intentions, not application code.

## The agents

The planner and executor are intentionally simple. They are not AI frameworks and they are not wrappers around Ollama.

They exist to create clear identity boundaries. The planner accepts user input but cannot reach the LLM. The executor can reach the LLM but cannot talk to users. This separation makes it obvious which identity is allowed to do what.

## Running the demo

You need Docker and [Task](https://taskfile.dev).

```bash
task up
```

## The demo flow

The demo is designed to be interactive. You start with a running system that cannot communicate. You then add intentions and watch traffic start flowing. When you remove an intention, traffic stops immediately.

```bash
task demo
```

Open Consul UI at http://localhost:8500 while the demo runs. Watch the intentions appear and disappear. Watch service health change.

After the guided demo, try `task chat` for interactive use.

| Task | What it does |
|------|--------------|
| `task up` | Start everything |
| `task down` | Stop everything |
| `task demo` | Guided walkthrough |
| `task chat` | Interactive chat |
| `task allow` | Create intentions |
| `task deny` | Delete intentions |
| `task logs` | Follow all logs |

## URLs

- Vault: http://localhost:8200 (token: `root`)
- Consul: http://localhost:8500
- Planner: http://localhost:8080

## Going deeper

See [docs/architecture.md](docs/architecture.md) for how Vault, Consul, and the sidecars fit together.

This demo uses Docker Compose so it runs anywhere Docker runs. The `nomad/` and `scripts/` directories contain a more realistic setup using Nomad and Linux networking. The architecture is the same. The tooling is heavier.
