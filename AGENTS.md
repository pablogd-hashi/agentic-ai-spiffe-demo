# AGENTS.md

## Cursor Cloud specific instructions

This repo is the **Agentic AI SPIFFE Demo**: a Docker Compose stack where a `planner`
agent calls an `executor` agent which calls `ollama`, with every hop secured by
mTLS via Consul Connect (Envoy sidecars), certificates issued by Vault PKI, and
authorization enforced by Consul intentions. There is no host-level app to run;
everything runs in containers. `Taskfile.yml` (`task`) wraps the workflow.

### Services (all containers, see `docker-compose.yml`)
- `vault` — PKI CA, UI at http://localhost:8200 (token `root`)
- `consul` — service mesh + intentions, UI at http://localhost:8500
- `ollama` — local LLM (`tinyllama`); model data persists in the `ollama-data` volume
- `planner` (:8080, exposed) → `executor` (:8081) → `ollama`, each with a `*-sidecar` Envoy proxy
- one-shot `bootstrap`/`*-register` containers configure PKI and register services, then exit (this is expected)

### Docker daemon (important, non-obvious)
Docker and `task` are preinstalled in the VM snapshot, but the Docker daemon is
**not** managed by systemd here. If `docker ps` fails with a socket error, start it:
```
sudo dockerd >/tmp/dockerd.log 2>&1 &
sudo chmod 666 /var/run/docker.sock   # if you hit permission denied on the socket
```
Give it ~5s to come up before running compose.

### Bring the stack up
`task up` is the documented one-shot (build + wait for bootstrap + pull model +
warm + create intentions). If you prefer step-by-step / non-interactive:
```
docker compose up -d --build
docker exec ollama ollama pull tinyllama
task allow            # create intentions; stack is DEFAULT-DENY without them
```
First `up` builds the Python agent images and pulls Vault/Consul/Ollama images.

### Testing / running (core flow)
Test the full mTLS chain with a plain HTTP call to the planner:
```
curl -s http://localhost:8080/ask -H 'Content-Type: application/json' \
  -d '{"question":"What is 2+2?"}'
```
Toggle authorization to see intentions enforced: `task deny` (→ HTTP 503 from
`/ask`) then `task allow` (→ 200). Allow ~5s for intentions to propagate.

### Gotchas
- **Interactive tasks**: `task demo` and `task chat` block on `read`/`input` and
  are not suitable for autonomous agents. Exercise the system with `curl` against
  `http://localhost:8080/ask` and the `task allow`/`task deny` subcommands instead.
- **Default deny**: with no intentions all traffic is blocked; you must run
  `task allow` (or `task up`) before `/ask` will succeed.
- **CPU inference**: keep prompts short; responses can take several seconds.
- There is no separate lint/unit-test suite in this repo; validation is the
  end-to-end request flow above.
- The Nomad path (`nomad/`, `scripts/`) is an alternative deployment and is not
  needed for the Docker Compose dev flow.
