# Agentic AI SPIFFE Demo

Three AI agents talking to each other over mTLS, authenticated by SPIFFE identities, authorized by Consul intentions.

No API keys. No network policies. No application-layer auth logic. Identity and authorization happen at the sidecar proxy, using certificates issued by Vault and enforced at runtime.

The point is to see how this works and why it's hard to misconfigure.

---

## What's in this demo

Three services:

- **planner-agent** — takes user questions, forwards them to the executor. Cannot talk to Ollama directly.
- **executor-agent** — receives requests from the planner, calls the LLM. Cannot accept user traffic.
- **ollama** — local inference. Unaware of agents, identity, or authorization.

The agents are minimal Flask apps. They're not AI frameworks and they don't wrap Ollama. They exist to create identity boundaries. The planner never talks to Ollama. The executor never talks to users. These constraints aren't convention — they're enforced by SPIFFE identities and Consul intentions.

Each service has a sidecar:
- **planner** + **planner-sidecar** (Consul Connect proxy)
- **executor** + **executor-sidecar** (Consul Connect proxy)
- **ollama** + **ollama-sidecar** (Consul Connect proxy)

Apps talk plain HTTP to `localhost`. The sidecar intercepts outbound calls, does the mTLS handshake with a Vault-issued cert, checks the intention, and either allows or drops the connection. Same process in reverse for inbound traffic.

Application code never touches crypto or identity.

---

## Prerequisites

- Docker (Desktop works)
- Task (https://taskfile.dev)

No Kubernetes, cloud account, or GPU required.

---

## Running the demo

```bash
task up
```

This starts Vault, Consul, the three services, and their sidecars. Then:
1. Bootstrap container configures Vault's PKI (root + intermediate CA)
2. Consul gets wired to Vault as its CA
3. `tinyllama` model gets pulled (600MB, first run only, cached in a volume)
4. Model gets warmed with a throwaway request

First run takes a couple minutes. Subsequent starts are faster.

Once it's up, run the guided walkthrough:

```bash
task demo
```

This walks through Vault's CA setup, SPIFFE IDs in certificates, default deny, creating intentions, and breaking the chain by removing one. It pauses at each step. Open the Consul UI while it runs:

```
http://localhost:8500
```

Watch services register, intentions appear and disappear, traffic get blocked or allowed.

After the walkthrough, try interactive chat:

```bash
task chat
```

Sends questions to the planner. Requests flow through planner → executor → Ollama with mTLS between each hop. Keep questions short — the model runs on CPU.

---

## What the demo shows

1. Services start. No intentions exist. All traffic denied by default.
2. Intentions get created: planner → executor, executor → ollama.
3. Traffic flows immediately. No restarts, no config reloads.
4. Remove one intention. Traffic stops instantly.

Failure modes are obvious. Authorization is explicit. Nothing works by accident.

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

**First run**: Downloads `tinyllama` (600MB). Cached in a Docker volume after that.

**Performance**: CPU inference. Short questions take a few seconds. Longer prompts take longer. No GPU needed.

**Bootstrap timing**: Services use health checks. Bootstrap waits for Vault and Consul before configuring PKI. If you see errors at first boot, wait 10 seconds and check `docker compose logs bootstrap`.

**Intentions**: Use `task allow` and `task deny` to manage intentions manually. Changes apply instantly.

---

## Service URLs

| Service | URL | Notes |
|---------|-----|-------|
| Vault | http://localhost:8200 | Token: `root` |
| Consul UI | http://localhost:8500 | |
| Planner API | http://localhost:8080 | |

---

## Going deeper

See `docs/architecture.md` for a detailed breakdown of Vault, Consul, SPIFFE identities, sidecars, and intentions.

This demo uses Docker Compose. Runs anywhere Docker runs.

The `nomad/` and `scripts/` directories have a heavier setup with Nomad, CNI, and Linux networking. Same architecture, more realistic sidecar injection. Use that if you want production-style behavior.
