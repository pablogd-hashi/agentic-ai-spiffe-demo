# Architecture

## Control plane and data plane

The system has two layers.

The **control plane** is Vault and Consul. They issue certificates, store configuration, and define authorization rules. During normal operation, they are not in the request path. If Vault goes down, traffic keeps flowing. Certificates are already issued. Consul caches what it needs.

The **data plane** is the agents and Ollama. They handle actual requests. Each service has an Envoy sidecar that terminates TLS and checks authorization. The sidecars do the work at runtime.

## How Vault and Consul work together

Vault runs a two-tier PKI. There is a root CA that signs an intermediate CA. The root private key never leaves Vault. Consul is configured to use the intermediate CA.

When a service starts, Consul generates a private key for its sidecar, creates a certificate signing request, and sends it to Vault. Vault signs it. Consul delivers the certificate to the sidecar. The application never sees this. It just makes HTTP calls to localhost.

Workloads never talk to Vault directly. They do not need Vault credentials. Consul handles everything.

Certificate rotation happens automatically. Before a cert expires, Consul requests a new one. The sidecar reloads without dropping connections.

## SPIFFE identity

Each service gets a SPIFFE ID. This is a URI embedded in the X.509 certificate as a Subject Alternative Name:

```
spiffe://dc1.consul/ns/default/dc/dc1/svc/planner-agent
spiffe://dc1.consul/ns/default/dc/dc1/svc/executor-agent
spiffe://dc1.consul/ns/default/dc/dc1/svc/ollama
```

When two services connect, they exchange certificates during the TLS handshake. The receiving sidecar extracts the SPIFFE ID from the client certificate and checks if that identity is allowed to connect.

The trust domain is `dc1.consul`. Consul picked this format. All services in the same Consul datacenter share the trust domain.

### Why X.509 and not JWT

SPIFFE defines two credential types: X.509-SVID and JWT-SVID.

X.509 works at the TLS layer. The private key never leaves the workload. If you intercept the certificate, you cannot impersonate the service because you do not have the key.

JWTs live at the application layer and behave like bearer tokens. If someone gets the token, they can replay it. JWTs are useful when you need to pass identity through systems that do not speak TLS, but they need more careful handling.

This demo uses X.509 only. The application code never touches certificates or tokens.

## Intentions

An intention is a rule: service A can connect to service B, or service A cannot connect to service B.

With no intentions, the default is **deny**. No service can connect to any other service. The sidecar rejects the connection before it reaches the application.

This is fail-safe. If you forget to configure something, traffic is blocked. You do not accidentally expose services.

Intentions are identity-based. The sidecar checks the SPIFFE ID in the client certificate, not the IP address. You can move services between hosts and authorization still works.

When you create or delete an intention, it takes effect within seconds. No restarts. The sidecars watch Consul for changes.

## The agent model

The agents are Flask apps. No memory, no planning loops, no tool calling. They exist to make identity boundaries visible.

### planner-agent

The planner is the entry point. Users send questions to it. It forwards them to the executor and returns the response.

The planner cannot call Ollama. There is no intention allowing it. If you tried to add a direct connection, the sidecar would block it.

In a real system, a planner might decompose tasks and coordinate multiple executors. Here it just forwards requests. The point is that it has a distinct identity from the thing it calls.

### executor-agent

The executor calls Ollama. It receives prompts from the planner, sends them to the LLM, and returns results.

The executor is the only service with an intention to reach Ollama. This is the authorization boundary. Even if something compromises the planner, it cannot reach the LLM directly.

In a real system, executors might access databases, payment APIs, or other sensitive resources. The pattern is the same: give the executor its own identity and grant access explicitly.

### ollama

Ollama is a local LLM runtime. In this demo it runs a small model on CPU.

Ollama represents any inference endpoint. It could be a managed API, a GPU cluster, or a fine-tuned model. The identity model does not care what is behind the service.

Inference is treated as a protected resource because it is. LLM calls can cost money, expose data through prompts, and produce outputs that need auditing. Limiting which identities can reach inference is basic hygiene.

## Request flow

```
User
  │
  │  POST /ask {"question": "..."}
  │
  ▼
┌──────────────────────┐
│    planner-agent     │  ← SPIFFE ID: .../svc/planner-agent
│      (Flask)         │
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
│      (Flask)         │
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
│     (LLM runtime)    │
└──────────────────────┘
```

The Flask apps make plain HTTP requests to localhost ports. The sidecars intercept, establish mTLS to the destination sidecar, and forward. The apps do not know about certificates or intentions.

## Docker Compose vs Nomad

This demo uses Docker Compose. It runs anywhere Docker runs.

The `nomad/` directory has job specs for the same architecture. Nomad provides proper sidecar injection and uses CNI for transparent proxying, which requires Linux. The `scripts/` directory has automation for running this on a Linux VM via Multipass.

The architecture is identical either way. Docker Compose is simpler. Nomad is closer to how you would run this in production.
