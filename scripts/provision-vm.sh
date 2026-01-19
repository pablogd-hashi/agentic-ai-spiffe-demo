#!/bin/bash
# VM Provisioning Script
# Runs on macOS host to create and provision the Multipass VM

set -e

VM_NAME="${VM_NAME:-agentic-demo}"
VM_CPUS="${VM_CPUS:-2}"
VM_MEMORY="${VM_MEMORY:-4G}"
VM_DISK="${VM_DISK:-20G}"
MAX_RETRIES=3

echo "=== Creating Multipass VM ==="
echo "Name: $VM_NAME"
echo "CPUs: $VM_CPUS"
echo "Memory: $VM_MEMORY"
echo "Disk: $VM_DISK"
echo ""

# Check if VM already exists
if multipass list | grep -q "^$VM_NAME"; then
    echo "VM '$VM_NAME' already exists."
    read -p "Delete and recreate? (y/N): " -n 1 -r
    echo
    if [[ $REPLY =~ ^[Yy]$ ]]; then
        echo "Deleting existing VM..."
        multipass delete "$VM_NAME"
        multipass purge
    else
        echo "Using existing VM. Skipping creation."
        VM_EXISTS=true
    fi
fi

# Create VM with retry logic
if [ "$VM_EXISTS" != "true" ]; then
    RETRY_COUNT=0
    while [ $RETRY_COUNT -lt $MAX_RETRIES ]; do
        echo "Launching VM (attempt $((RETRY_COUNT + 1))/$MAX_RETRIES)..."

        # macOS doesn't have timeout by default, so we rely on multipass's --timeout flag
        if multipass launch 22.04 \
            --name "$VM_NAME" \
            --cpus "$VM_CPUS" \
            --memory "$VM_MEMORY" \
            --disk "$VM_DISK" \
            --timeout 300; then
            echo "VM launched successfully"
            break
        else
            RETRY_COUNT=$((RETRY_COUNT + 1))
            if [ $RETRY_COUNT -lt $MAX_RETRIES ]; then
                echo "Launch failed. Cleaning up and retrying..."
                multipass delete "$VM_NAME" 2>/dev/null || true
                multipass purge 2>/dev/null || true
                sleep 5
            else
                echo ""
                echo "ERROR: Failed to create VM after $MAX_RETRIES attempts"
                echo ""
                echo "Troubleshooting steps:"
                echo "  1. Check Multipass status: multipass version"
                echo "  2. Restart Multipass daemon:"
                echo "     sudo launchctl stop com.canonical.multipassd"
                echo "     sudo launchctl start com.canonical.multipassd"
                echo "  3. Try with fewer resources: VM_MEMORY=2G VM_CPUS=1 $0"
                echo "  4. Check system resources: vm_stat | head -10"
                echo "  5. Try manual creation:"
                echo "     multipass launch 22.04 --name $VM_NAME --cpus 2 --memory 4G --disk 20G"
                echo "  6. View Multipass logs:"
                echo "     tail -f /Library/Logs/Multipass/multipassd.log"
                echo ""
                exit 1
            fi
        fi
    done
fi

# Wait for VM to be ready
echo ""
echo "=== Waiting for VM to be ready ==="
READY_COUNT=0
while [ $READY_COUNT -lt 30 ]; do
    if multipass exec "$VM_NAME" -- echo "VM Ready" 2>/dev/null; then
        echo "VM is ready"
        break
    fi
    echo "Waiting... ($((READY_COUNT + 1))/30)"
    sleep 2
    READY_COUNT=$((READY_COUNT + 1))
done

if [ $READY_COUNT -eq 30 ]; then
    echo "ERROR: VM did not become ready in time"
    echo "Try: multipass info $VM_NAME"
    exit 1
fi

echo ""
echo "=== VM Info ==="
multipass info "$VM_NAME"

echo ""
echo "=== Copying demo files to VM ==="
# Ensure destination directory exists
multipass exec "$VM_NAME" -- mkdir -p /home/ubuntu/demo

# Copy files
if multipass transfer -r . "$VM_NAME":/home/ubuntu/demo/; then
    echo "Files copied successfully"
else
    echo "ERROR: Failed to copy files"
    echo "Try manually: multipass transfer -r . $VM_NAME:/home/ubuntu/demo/"
    exit 1
fi

echo ""
echo "=== Installing dependencies in VM ==="
echo "This may take 5-10 minutes..."
if multipass exec "$VM_NAME" -- bash -c 'cd /home/ubuntu/demo && bash scripts/install-deps.sh'; then
    echo "Dependencies installed successfully"
else
    echo "WARNING: Dependency installation may have failed"
    echo "You can complete installation manually:"
    echo "  multipass shell $VM_NAME"
    echo "  cd ~/demo"
    echo "  bash scripts/install-deps.sh"
fi

echo ""
echo "=== Provisioning Complete ==="
echo ""
echo "VM IP: $(multipass info "$VM_NAME" | grep IPv4 | awk '{print $2}')"
echo ""
echo "Next steps:"
echo "  1. Shell into VM: multipass shell $VM_NAME"
echo "  2. Run bootstrap: cd ~/demo && task bootstrap"
echo "  3. Create intentions: task consul:intentions:create"
echo "  4. Start chatting: task chat"
echo ""
echo "Or run the full automated setup:"
echo "  multipass exec $VM_NAME -- bash -c 'cd /home/ubuntu/demo && bash scripts/bootstrap-all.sh'"
echo ""
echo "Access UIs (from macOS):"
echo "  Vault:  http://$(multipass info "$VM_NAME" | grep IPv4 | awk '{print $2}'):8200"
echo "  Consul: http://$(multipass info "$VM_NAME" | grep IPv4 | awk '{print $2}'):8500"
echo "  Nomad:  http://$(multipass info "$VM_NAME" | grep IPv4 | awk '{print $2}'):4646"
