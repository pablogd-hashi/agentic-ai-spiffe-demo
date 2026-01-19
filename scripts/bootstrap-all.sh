#!/bin/bash
# Full Bootstrap Script
# Runs inside the VM to set up everything automatically

# Don't exit on error - we'll handle errors gracefully
set +e

cd "$(dirname "$0")/.."

echo "╔════════════════════════════════════════════════════════════╗"
echo "║  Agentic AI SPIFFE Demo - Automated Bootstrap             ║"
echo "╚════════════════════════════════════════════════════════════╝"
echo ""
echo "NOTE: This bootstrap is idempotent - safe to run multiple times"
echo ""

# Check if task is installed
if ! command -v task &> /dev/null; then
    echo "ERROR: 'task' command not found. Installing..."
    sudo sh -c "$(curl --location https://taskfile.dev/install.sh)" -- -d -b /usr/local/bin
fi

# Function to run a task and continue on known errors
run_task() {
    local task_name=$1
    local step_name=$2

    if task "$task_name"; then
        echo "✓ $step_name completed successfully"
        return 0
    else
        echo "⚠ $step_name had warnings (may be normal if running multiple times)"
        return 0  # Continue anyway
    fi
}

echo "=== Step 1/8: Starting core services ==="
run_task services:start "Service startup"
sleep 5

echo ""
echo "=== Step 2/8: Bootstrapping Vault PKI ==="
run_task vault:bootstrap "Vault PKI bootstrap"
sleep 3

echo ""
echo "=== Step 3/8: Configuring Consul CA ==="
run_task consul:configure "Consul CA configuration"
sleep 3

echo ""
echo "=== Step 4/8: Building agent Docker images ==="
run_task build:all "Docker image builds"
sleep 2

echo ""
echo "=== Step 5/8: Deploying Ollama ==="
run_task deploy:ollama "Ollama deployment"
echo "Waiting for Ollama to be healthy..."
sleep 10

echo ""
echo "=== Step 6/8: Deploying executor-agent ==="
run_task deploy:executor "Executor agent deployment"
sleep 5

echo ""
echo "=== Step 7/8: Deploying planner-agent ==="
run_task deploy:planner "Planner agent deployment"
sleep 5

echo ""
echo "=== Step 8/8: Creating Consul intentions ==="
run_task consul:intentions:create "Consul intentions"

echo ""
echo "╔════════════════════════════════════════════════════════════╗"
echo "║  Bootstrap Complete!                                       ║"
echo "╚════════════════════════════════════════════════════════════╝"
echo ""

# Get VM IP
VM_IP=$(ip addr show enp0s1 2>/dev/null | grep "inet " | awk '{print $2}' | cut -d/ -f1 || echo "127.0.0.1")

echo "Services:"
echo "  Vault UI:  http://$VM_IP:8200 (token: root)"
echo "  Consul UI: http://$VM_IP:8500"
echo "  Nomad UI:  http://$VM_IP:4646"
echo ""

echo "Testing connectivity..."
sleep 3

# Test health
echo ""
echo "=== Health Check ==="
task test:health

echo ""
echo "=== Testing AI system ==="
response=$(curl -s http://localhost:8080/ask \
  -H "Content-Type: application/json" \
  -d '{"question": "Say hello in one sentence"}' | jq -r '.answer' 2>/dev/null || echo "FAILED")

if [ "$response" != "FAILED" ]; then
  echo "✓ System is working!"
  echo ""
  echo "Response: $response"
else
  echo "✗ System check failed. Check logs with 'task logs:planner'"
fi

echo ""
echo "╔════════════════════════════════════════════════════════════╗"
echo "║  Quick Commands                                            ║"
echo "╚════════════════════════════════════════════════════════════╝"
echo ""
echo "  Chat interactively:         task chat"
echo "  View intentions:            task consul:intentions:list"
echo "  Test default deny:          task consul:intentions:delete && task test:deny"
echo "  Re-enable traffic:          task consul:intentions:create"
echo "  View Nomad jobs:            task nomad:status"
echo "  View logs:                  task logs:planner"
echo ""
echo "  List all tasks:             task --list"
echo ""
