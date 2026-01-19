# Architecture

## Overview

This demo has two layers: control plane and data plane.

**Control plane**: Vault and Consul. They issue certificates, store configuration, and enforce authorization. They are not in the request path during normal operation.

**Data plane**: The agents and Ollama. They handle actual traffic. Each service has an Envoy sidecar that terminates mTLS and checks authorization.

Vault and Consul configure the system. Envoy sidecars enforce the rules at runtime.

## Identity model (SPIFFE)

Each service gets a SPIFFE ID. This is a URI that identifies the workload:

```
spiffe://dc1.consul/ns/default/dc/dc1/svc/planner-agent
spiffe://dc1.consul/ns/default/dc/dc1/svc/executor-agent
spiffe://dc1.consul/ns/default/dc/dc1/svc/ollama
```

The trust domain is `dc1.consul`. Consul chose this format. All services in this Consul datacenter share the same trust domain.

The SPIFFE ID is embedded in the X.509 certificate as a Subject Alternative Name (SAN) URI. When two services connect via mTLS, they exchange certificates. The receiving sidecar extracts the SPIFFE ID from the certificate and checks if that identity is allowed to connect.

This is called an X.509-SVID (SPIFFE Verifiable Identity Document). There is also JWT-SVID for cases where you need to pass identity through HTTP headers, but this demo uses X.509 only. TLS handles everything.

The application code does not see any of this. The Flask apps make plain HTTP requests to localhost. The sidecar intercepts, establishes mTLS, and forwards. The identity verification happens in the sidecar, not in application code.

## Vault PKI setup

Vault runs a two-tier PKI hierarchy.

**Root CA** (`pki/`): Self-signed certificate with 10-year TTL. The root private key stays in Vault and is never exported. This CA only signs intermediate certificates.

**Intermediate CA** (`pki_int/`): Signed by the root CA. 5-year TTL. This CA signs workload certificates. Consul uses this intermediate to issue certificates to services.

Why two tiers? If the intermediate is compromised, you can revoke it and create a new one. The root CA is offline most of the time. This is standard PKI practice.

The bootstrap script does the following:

1. Enable PKI secrets engine at `pki/`
2. Generate root CA certificate
3. Enable PKI secrets engine at `pki_int/`
4. Generate intermediate CSR
5. Sign intermediate with root CA
6. Import signed intermediate back to `pki_int/`
7. Create a role `consul-connect` that allows Consul to request certificates

Certificate TTL for workloads is 72 hours. Consul rotates certificates before they expire. Short TTLs limit damage if a certificate is stolen.

## Consul as CA and authorization engine

Consul is configured to use Vault as its CA provider. When Consul needs to issue a certificate to a service, it sends a CSR to Vault's intermediate CA and gets back a signed certificate.

```json
{
  "Provider": "vault",
  "Config": {
    "Address": "http://vault:8200",
    "Token": "root",
    "RootPKIPath": "pki",
    "IntermediatePKIPath": "pki_int"
  }
}
```

Consul handles the rest:
- Generates private keys for sidecars (keys never leave the sidecar)
- Creates CSRs with SPIFFE IDs
- Sends CSRs to Vault
- Delivers signed certificates to sidecars
- Rotates certificates before expiration

Consul also enforces authorization through intentions. An intention is a rule that says "service A can connect to service B" or "service A cannot connect to service B".

With no intentions, the default is deny. No service can connect to any other service. This is fail-safe. Misconfiguration blocks traffic instead of allowing unauthorized access.

Intentions are identity-based, not network-based. The sidecar does not check IP addresses. It checks the SPIFFE ID in the client certificate. You can move services between hosts and the authorization still works.

## Agent model

There are two agents in this demo: planner and executor.

**Planner agent**: Entry point for user requests. Receives HTTP POST with a question. Forwards the question to the executor. Returns the answer to the user.

**Executor agent**: Calls Ollama for inference. Receives requests from the planner. Sends prompts to Ollama. Returns the response.

Why two agents? To show identity boundaries.

In a real system, a planner might decompose tasks and call multiple executors. An executor might have access to sensitive resources like databases or payment APIs. The separation makes it clear who can access what.

In this demo:
- Planner can call executor
- Executor can call Ollama
- Planner cannot call Ollama directly

This is enforced by intentions. If you delete the `planner-agent → executor-agent` intention, the planner cannot reach the executor even though both are running.

The agents are simple Flask apps. They are not AI frameworks. They do not have memory, planning, or tool use. They exist to show how identity works, not to show AI capabilities.

### Traffic flow

```
User
  │
  │ HTTP POST /ask
  ▼
┌─────────────────┐
│  planner-agent  │ ◄── SPIFFE ID: spiffe://dc1.consul/.../svc/planner-agent
│  (Flask app)    │
└────────┬────────┘
         │
         │ HTTP to localhost:9001 (upstream)
         ▼
┌─────────────────┐
│ planner sidecar │ ◄── Envoy proxy
│                 │
└────────┬────────┘
         │
         │ mTLS
         │ (checks intention: planner → executor)
         ▼
┌─────────────────┐
│executor sidecar │ ◄── Envoy proxy
│                 │
└────────┬────────┘
         │
         │ HTTP to localhost:8081
         ▼
┌─────────────────┐
│ executor-agent  │ ◄── SPIFFE ID: spiffe://dc1.consul/.../svc/executor-agent
│  (Flask app)    │
└────────┬────────┘
         │
         │ HTTP to localhost:9002 (upstream)
         ▼
┌─────────────────┐
│executor sidecar │
│                 │
└────────┬────────┘
         │
         │ mTLS
         │ (checks intention: executor → ollama)
         ▼
┌─────────────────┐
│  ollama sidecar │ ◄── Envoy proxy
│                 │
└────────┬────────┘
         │
         │ HTTP to localhost:11434
         ▼
┌─────────────────┐
│     ollama      │ ◄── SPIFFE ID: spiffe://dc1.consul/.../svc/ollama
│   (LLM runtime) │
└─────────────────┘
```

The Flask apps make plain HTTP requests to localhost. The sidecars handle mTLS. The apps do not know about certificates, intentions, or SPIFFE.

### Required intentions

For the full flow to work, you need two intentions:

```bash
consul intention create planner-agent executor-agent
consul intention create executor-agent ollama
```

If you delete the first one, planner cannot reach executor. If you delete the second one, executor cannot reach Ollama. The demo shows this by testing requests before and after creating intentions.

## Ollama in this demo

Ollama is a local LLM runtime. It runs models on CPU (no GPU required for this demo). The model used is `qwen2.5:0.5b`, which is small and fast.

Ollama represents any inference service. It could be replaced with OpenAI API, Anthropic API, or a private model server. The identity model does not care what is behind the API.

Why treat inference as a protected resource? Because it is. LLM inference can:
- Cost money per request
- Expose training data through prompts
- Generate outputs that need auditing
- Access tools and databases

In this demo, only the executor can call Ollama. The planner cannot. This limits blast radius. If someone compromises the planner, they still cannot reach the LLM directly.

## Docker Compose vs Nomad

This demo uses Docker Compose. It runs on any machine with Docker.

The `nomad/` directory contains Nomad job specs for the same architecture. Nomad provides:
- Proper sidecar injection via Consul Connect integration
- CNI-based transparent proxy (no application changes)
- Multi-host scheduling

The `scripts/` directory contains scripts for running with Nomad on a Linux VM via Multipass. Use this if you want a more realistic setup.

The architecture is the same in both cases:
- Vault issues certificates
- Consul manages sidecars and intentions
- Services communicate through mTLS

Docker Compose is simpler to run. Nomad is closer to production. Choose based on your goal.

## System diagram

```
┌─────────────────────────────────────────────────────────────────────────┐
│                           CONTROL PLANE                                 │
│  ┌─────────────┐         ┌─────────────┐                               │
│  │    Vault    │────────▶│   Consul    │                               │
│  │  (Root CA)  │  signs  │(Intermediate│                               │
│  │             │  int CA │     CA)     │                               │
│  └─────────────┘         └──────┬──────┘                               │
│                                 │                                       │
│                    issues certs │ enforces intentions                   │
│                                 │                                       │
└─────────────────────────────────┼───────────────────────────────────────┘
                                  │
┌─────────────────────────────────┼───────────────────────────────────────┐
│                           DATA PLANE                                    │
│                                 │                                       │
│                                 ▼                                       │
│  ┌─────────────────────────────────────────────────────────────────┐   │
│  │                                                                 │   │
│  │   ┌─────────┐    mTLS     ┌─────────┐    mTLS     ┌─────────┐  │   │
│  │   │ planner │◄───────────▶│executor │◄───────────▶│ ollama  │  │   │
│  │   │ +sidecar│  intention  │+sidecar │  intention  │+sidecar │  │   │
│  │   └─────────┘             └─────────┘             └─────────┘  │   │
│  │                                                                 │   │
│  │   Intentions:                                                   │   │
│  │     planner-agent ──▶ executor-agent  (allowed)                │   │
│  │     executor-agent ──▶ ollama         (allowed)                │   │
│  │     planner-agent ──▶ ollama          (denied - no intention)  │   │
│  │                                                                 │   │
│  └─────────────────────────────────────────────────────────────────┘   │
│                                                                         │
└─────────────────────────────────────────────────────────────────────────┘
```

Vault and Consul are control plane. They configure the system but are not in the request path.

The agents and Ollama are data plane. Traffic flows through their sidecars. The sidecars enforce mTLS and check intentions.

If Vault goes offline, the system keeps running. Certificates are already issued. Consul handles rotation using cached credentials. This is why the control plane is separate from the data plane.
