# Architecture

## Control plane and data plane

The system is split into two layers.

The **control plane** consists of Vault and Consul. This layer is responsible for issuing identities, managing trust, and defining authorization rules. It is not involved in handling application requests during normal operation. Once certificates are issued and policies are in place, traffic flows without Vault or Consul being on the request path.

If Vault becomes unavailable, existing services continue to communicate using already issued certificates. Consul caches the information it needs to enforce policy locally.

The **data plane** consists of the agents and the Ollama service. These components handle actual application traffic. Each service runs alongside an Envoy sidecar that terminates TLS, verifies peer identity, and enforces authorization decisions. All runtime enforcement happens here.

---

## How Vault and Consul work together

Vault provides a two-tier PKI hierarchy. A root certificate authority signs an intermediate certificate authority. The root private key never leaves Vault and is only used to sign intermediates. Consul is configured to use the intermediate CA to issue workload certificates.

When a service starts, Consul generates a private key for the sidecar, creates a certificate signing request, and sends it to Vault. Vault signs the request using the intermediate CA and returns the certificate. Consul delivers the certificate to the sidecar.

The application never sees certificates or keys. It simply makes HTTP calls to localhost.

Workloads never authenticate to Vault directly and do not need Vault credentials. All certificate issuance and rotation is handled by Consul on their behalf.

Certificates are short-lived and rotated automatically. Before a certificate expires, Consul requests a new one and the sidecar reloads it without dropping connections.

---

## SPIFFE identity

Each service is assigned a SPIFFE ID. This is a URI embedded in the X.509 certificate as a Subject Alternative Name:

```
spiffe://dc1.consul/ns/default/dc/dc1/svc/planner-agent
spiffe://dc1.consul/ns/default/dc/dc1/svc/executor-agent
spiffe://dc1.consul/ns/default/dc/dc1/svc/ollama
```

When two services connect, they exchange certificates as part of the TLS handshake. Each sidecar verifies the peer certificate and extracts the SPIFFE ID. Authorization decisions are made based on that identity.

The trust domain here is `dc1.consul`. This format is chosen by Consul. All services registered in the same Consul datacenter share the trust domain.

### Why X.509 and not JWT

SPIFFE defines two credential formats: X.509-SVID and JWT-SVID.

X.509 credentials operate at the TLS layer. Authentication happens during the handshake and is bound to possession of a private key. Even if a certificate is intercepted, it cannot be used to impersonate a service without the corresponding key.

JWT credentials operate at the application layer and behave like bearer tokens. Anyone in possession of the token can replay it. JWTs are useful in environments where mutual TLS is not possible, but they require additional care to avoid leakage and misuse.

This demo uses X.509 exclusively. Identity verification happens transparently in the sidecars. The application code does not handle certificates or tokens.

---

## Intentions

An intention is an explicit rule that allows or denies communication between two services.

With no intentions defined, the default behavior is **deny**. No service can talk to any other service. Connections are rejected by the sidecar before they reach the application.

This makes failure modes predictable. Missing configuration results in blocked traffic rather than unintended access.

Intentions are evaluated based on identity, not network location. The sidecar checks the SPIFFE ID presented in the client certificate, not IP addresses. Services can move between hosts without changing authorization behavior.

Changes to intentions take effect within seconds. No restarts are required. Sidecars watch Consul for policy updates and apply them dynamically.

---

## The agent model

The agents in this demo are simple Flask applications. They have no memory, planning logic, or tool orchestration. Their purpose is to make identity boundaries and authorization paths explicit.

### planner-agent

The planner is the entry point for user requests. It accepts questions, forwards them to the executor, and returns the response.

The planner has no permission to call Ollama directly. There is no intention allowing that path. Any attempt to bypass the executor would be blocked by the sidecar.

In a real system, a planner might coordinate multiple executors or decompose tasks. Here it simply forwards requests. The important part is that it has a distinct identity from the service it calls.

### executor-agent

The executor receives requests from the planner and calls Ollama for inference. It returns the result back to the planner.

The executor is the only service with permission to reach Ollama. This is the key authorization boundary. Even if the planner is compromised, it cannot access the LLM directly.

In real deployments, executors might access databases, external APIs, or other sensitive systems. The pattern is the same: give each role its own identity and grant access explicitly.

### ollama

Ollama is a local LLM runtime. In this demo it runs a small model on CPU.

It represents any inference service: a managed API, a private model server, or a GPU-backed cluster. The identity and authorization model does not depend on what runs behind the service.

Inference is treated as a protected capability. LLM calls can be expensive, may expose sensitive context through prompts, and produce outputs that require auditing. Restricting which identities can access inference reduces risk and limits blast radius.

---

## Request flow

```
User
  │
  │  POST /ask {"question": "..."}
  │
  ▼
┌──────────────────────┐
│    planner-agent     │  ← SPIFFE ID: .../svc/planner-agent
│       (Flask)        │
└──────────┬───────────┘
           │
           │  HTTP to localhost:9001
           ▼
┌──────────────────────┐
│   planner sidecar    │  ← Envoy
└──────────┬───────────┘
           │
           │  mTLS ─────────────────────────┐
           │                                │
           ▼                                │ intention check:
┌──────────────────────┐                    │ planner-agent → executor-agent
│   executor sidecar   │  ← Envoy           │
└──────────┬───────────┘                    │
           │                                │
           │  HTTP to localhost:8081  ◄─────┘
           ▼
┌──────────────────────┐
│   executor-agent     │  ← SPIFFE ID: .../svc/executor-agent
│       (Flask)        │
└──────────┬───────────┘
           │
           │  HTTP to localhost:9002
           ▼
┌──────────────────────┐
│   executor sidecar   │  ← Envoy
└──────────┬───────────┘
           │
           │  mTLS ─────────────────────────┐
           │                                │
           ▼                                │ intention check:
┌──────────────────────┐                    │ executor-agent → ollama
│    ollama sidecar    │  ← Envoy           │
└──────────┬───────────┘                    │
           │                                │
           │  HTTP to localhost:11434 ◄─────┘
           ▼
┌──────────────────────┐
│       ollama         │  ← SPIFFE ID: .../svc/ollama
│    (LLM runtime)     │
└──────────────────────┘
```

The applications make plain HTTP requests to localhost. The sidecars intercept traffic, establish mutual TLS with the destination sidecar, and enforce authorization. The applications are unaware of certificates, identities, or intentions.

---

## Docker Compose vs Nomad

This demo uses Docker Compose to keep the setup simple and portable.

The `nomad/` directory contains job specifications for running the same architecture with Nomad. Nomad provides native Consul Connect integration, proper sidecar injection, and CNI-based transparent proxying, which requires Linux.

The `scripts/` directory includes automation for running the Nomad setup inside a Linux VM using Multipass.

The architecture is the same in both cases. Docker Compose is easier to run locally. Nomad is closer to production.
