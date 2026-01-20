# Agentic AI SPIFFE Demo

This demo shows how workload identity and authorization behave when AI services communicate with each other.

Instead of API keys or network-based trust, services authenticate using **SPIFFE identities**, establish **mutual TLS**, and rely on **Consul intentions** for authorization. Identity and policy are enforced at runtime by sidecar proxies, not application code.

The goal is to make these mechanics visible, observable, and hard to get wrong.

---

## What's in this demo

The system consists of three services:

- **planner-agent**
  Entry point for user requests. Accepts questions but cannot reach the LLM directly.

- **executor-agent**
  Receives requests from the planner and calls the LLM. Cannot accept user traffic.

- **ollama**
  Local inference service. No awareness of agents, identity, or authorization.

The agents are intentionally simple Flask applications. They are not AI frameworks and they are not wrappers around Ollama.

They exist to create **clear identity boundaries** and to demonstrate how authorization is enforced between services. The planner never talks to Ollama. The executor never talks to users. Those constraints are enforced by identity and policy, not convention.

---

## Prerequisites

You only need:

- **Docker**
  Docker Desktop works fine.

- **Task**
  https://taskfile.dev

---

## Running the demo

Start all services:

```bash
task up
```

Once everything is running, start the guided walkthrough:

```bash
task demo
```

The demo is interactive and pauses at each step so you can inspect what's happening.

While it runs, open the Consul UI:

```
http://localhost:8500
```

You can watch services register, intentions appear and disappear, and traffic get allowed or denied in real time.

After the walkthrough, try the interactive chat:

```bash
task chat
```

This lets you ask arbitrary questions and see how requests flow through the planner, executor, and Ollama.

---

## What the demo shows

The flow is intentionally simple and repeatable:

1. **Services start with no intentions**
   All traffic is denied by default.

2. **Intentions are created**
   - planner-agent → executor-agent
   - executor-agent → ollama

3. **Traffic starts flowing immediately**
   No restarts. No config reloads.

4. **An intention is removed**
   Traffic stops instantly.

This makes failure modes obvious and safe. Authorization is explicit. Nothing works by accident.

---

## Common tasks

| Command | Description |
|---------|-------------|
| `task up` | Start all services |
| `task down` | Stop everything |
| `task demo` | Guided walkthrough |
| `task chat` | Interactive chat interface |

---

## Service URLs

| Service | URL | Notes |
|---------|-----|-------|
| Vault | http://localhost:8200 | Token: `root` |
| Consul UI | http://localhost:8500 | |
| Planner API | http://localhost:8080 | |

---

## Going deeper

For a detailed explanation of how Vault, Consul, SPIFFE identities, sidecars, and intentions fit together, see:

```
docs/architecture.md
```

This demo uses Docker Compose so it runs anywhere Docker runs.

The `nomad/` and `scripts/` directories contain a more realistic setup using Nomad, CNI, and Linux networking. The architecture is the same. The setup is heavier. Use it if you want to explore production-style sidecar injection and networking.
