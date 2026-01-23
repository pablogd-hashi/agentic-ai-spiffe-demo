# Nomad Setup

Production-style deployment using Nomad with native Consul Connect integration, proper sidecar injection, and CNI-based transparent proxying.

This setup requires Linux. On macOS, use Multipass to run a Linux VM.

## Prerequisites

- [Multipass](https://multipass.run/) (macOS/Windows)

## Step 1: Create the VM

From the project root:

```bash
bash scripts/provision-vm.sh
```

This creates an Ubuntu 22.04 VM with:
- 2 CPUs, 4GB RAM, 20GB disk (configurable via `VM_CPUS`, `VM_MEMORY`, `VM_DISK`)
- Docker, Vault, Consul, Nomad, Ollama installed
- CNI plugins for Consul Connect

## Step 2: Bootstrap the Stack

Shell into the VM and run the bootstrap:

```bash
multipass shell agentic-demo
cd ~/demo
bash scripts/bootstrap-all.sh
```

This will:
1. Start Vault, Consul, and Nomad
2. Configure Vault PKI (root + intermediate CA)
3. Wire Consul to Vault as its CA
4. Build and deploy the agent containers via Nomad
5. Create Consul intentions
6. Run a health check

## Step 3: Access the UIs

Get the VM IP:

```bash
multipass info agentic-demo | grep IPv4
```

Access from your host:

| Service | URL |
|---------|-----|
| Vault | `http://<VM_IP>:8200` (token: `root`) |
| Consul | `http://<VM_IP>:8500` |
| Nomad | `http://<VM_IP>:4646` |

## Step 4: Chat with the Agents

Inside the VM:

```bash
task chat
```

## Commands (inside VM)

| Command | Description |
|---------|-------------|
| `task nomad:status` | View Nomad job status |
| `task consul:intentions:list` | List intentions |
| `task consul:intentions:create` | Create intentions |
| `task consul:intentions:delete` | Delete intentions |
| `task test:health` | Run health checks |
| `task logs:planner` | View planner logs |
| `task logs:executor` | View executor logs |

## VM Management

```bash
# Stop the VM
multipass stop agentic-demo

# Start the VM
multipass start agentic-demo

# Delete the VM
multipass delete agentic-demo && multipass purge
```

## Customizing the VM

```bash
VM_NAME=my-demo VM_CPUS=4 VM_MEMORY=8G bash scripts/provision-vm.sh
```

## Troubleshooting

**VM creation fails:**
```bash
# Restart Multipass daemon (macOS)
sudo launchctl stop com.canonical.multipassd
sudo launchctl start com.canonical.multipassd
```

**Services not starting:**
```bash
# Check Nomad jobs
nomad status

# Check Consul services
consul catalog services

# View logs
journalctl -u nomad -f
```

**CNI issues:**
```bash
# Verify CNI plugins
ls /opt/cni/bin/

# Re-run CNI install
bash scripts/install-cni.sh
```
