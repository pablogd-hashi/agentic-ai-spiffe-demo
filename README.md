# Agentic AI SPIFFE Demo

AI agents communicating over mTLS, authenticated via SPIFFE identities and authorized by Consul intentions.

```
User → planner-agent → executor-agent → ollama
            ↓               ↓              ↓
        [sidecar]       [sidecar]      [sidecar]
            └───── mTLS ─────┴───── mTLS ─────┘
```

## What You're Deploying

**[Vault](https://www.vaultproject.io/)** — Secrets management and PKI. Vault runs a two-tier certificate authority (root CA + intermediate CA) that issues short-lived X.509 certificates. Workloads never touch Vault directly—Consul handles certificate requests on their behalf.

**[Consul](https://www.consul.io/)** — Service mesh and service discovery. Consul requests certificates from Vault, distributes them to Envoy sidecars, and enforces authorization through intentions. Intentions are identity-based rules that allow or deny service-to-service communication.

**[SPIFFE](https://spiffe.io/)** — A standard for service identity. Each service gets a SPIFFE ID embedded in its X.509 certificate as a URI Subject Alternative Name (SAN):

```
X509v3 Subject Alternative Name: critical
    URI:spiffe://dc1.consul/ns/default/dc/dc1/svc/executor-agent
```

Sidecars verify these identities during mTLS handshake. Applications just make plain HTTP calls to localhost.

**Agents** — Three services demonstrating identity boundaries:
- `planner-agent` — receives user requests, forwards to executor
- `executor-agent` — calls the LLM
- `ollama` — local inference (tinyllama)

For detailed architecture, see [docs/architecture.md](docs/architecture.md).

## Prerequisites

- [Docker](https://docs.docker.com/get-docker/)
- [Task](https://taskfile.dev)

## Step 1: Start the Stack

```bash
task up
```

This will:
- Configure Vault's PKI (root + intermediate CA)
- Wire Consul to Vault as its CA
- Pull the `tinyllama` model (~600MB, first run only)
- Warm the model with a test request

## Step 2: Run the Demo Walkthrough

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

## Running with Nomad

The default setup uses Docker Compose for simplicity. For a production-style deployment with proper sidecar injection and CNI networking, use the Nomad setup.

Nomad requires Linux. On macOS, use Multipass to run a Linux VM.

See [nomad/README.md](nomad/README.md) for instructions.

## Notes

- **Performance**: Model runs on CPU. Keep prompts short.
- **Certificates**: Short-lived and auto-rotated by Consul. No manual renewal needed.
- **Default deny**: With no intentions, all traffic is blocked. Explicit allow required.
