# Agentic AI SPIFFE Demo

This demo shows how workload identity and authorization behave when AI services communicate with each other.

Instead of API keys or network-based trust, services authenticate using SPIFFE identities, establish mutual TLS, and rely on Consul intentions for authorization. Identity and policy are enforced at runtime by sidecar proxies, not application code.

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

Each service runs with a sidecar proxy:
- **planner** + **planner-sidecar** (Consul Connect proxy running Envoy)
- **executor** + **executor-sidecar** (Consul Connect proxy running Envoy)
- **ollama** + **ollama-sidecar** (Consul Connect proxy running Envoy)

The agents talk to `localhost`. The sidecar intercepts outbound connections, performs the mTLS handshake using certificates from Vault, checks intentions, and proxies traffic if allowed. Inbound traffic goes through the same process in reverse.

The application code sees plain HTTP. The sidecar does the crypto and identity checks.

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

This does several things in sequence:
1. Spins up Vault, Consul, and the three services with their sidecar proxies
2. Runs a bootstrap job that configures Vault's PKI hierarchy and wires Consul to use it as a CA
3. Pulls the `tinyllama` model (first run only — it's about 600MB)
4. Warms up the model with a throwaway request so the first real query isn't slow

The whole process takes a minute or two the first time. Subsequent starts are faster because the model is cached in a volume.

Once everything is running, start the guided walkthrough:

```bash
task demo
```

The demo is interactive and pauses at each step so you can inspect what's happening. It walks through:
- Vault's root and intermediate CA setup
- SPIFFE IDs embedded in service certificates
- Default deny behavior (no intentions = blocked traffic)
- Creating intentions and watching traffic flow
- Removing an intention to break the chain

While it runs, open the Consul UI:

```
http://localhost:8500
```

You can watch services register, intentions appear and disappear, and traffic get allowed or denied in real time.

After the walkthrough, try the interactive chat:

```bash
task chat
```

This is a Python script that sends questions to the planner. You'll see requests flow through the planner, executor, and Ollama with full mTLS enforcement between each hop.

Keep questions short. The model runs on CPU and longer prompts take longer to answer.

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
| `task allow` | Create intentions manually |
| `task deny` | Delete intentions manually |
| `task logs` | Follow all container logs |

---

## Notes

**First run**: The `tinyllama` model gets pulled on first start. It's about 600MB. This happens once and gets cached in a Docker volume.

**Performance**: The model runs on CPU. Answers to short questions come back in a few seconds. Longer prompts take longer. This is intentional — the demo doesn't require a GPU.

**Bootstrap timing**: Services start with health checks. The bootstrap container waits for Vault and Consul to be ready before configuring PKI. If you see errors on first boot, wait 10 seconds and check `docker compose logs bootstrap`. It usually means something hadn't started yet.

**Intentions**: You can create and delete intentions manually with `task allow` and `task deny`. Changes take effect immediately — no restarts needed.

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
