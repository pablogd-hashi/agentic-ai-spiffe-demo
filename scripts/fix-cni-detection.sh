#!/bin/bash
# Fix CNI Plugin Detection in Nomad
# This script ensures Nomad can detect and use CNI plugins

set -e

echo "=== CNI Detection Fix Script ==="
echo ""

# Step 1: Verify CNI plugins exist
echo "Step 1: Verifying CNI plugins exist..."
if [ ! -f /opt/cni/bin/bridge ]; then
    echo "ERROR: CNI plugins not found in /opt/cni/bin/"
    echo "Run: bash scripts/install-cni.sh first"
    exit 1
fi

echo "✓ CNI plugins found"
ls -lh /opt/cni/bin/ | head -10
echo ""

# Step 2: Ensure plugins are executable
echo "Step 2: Ensuring CNI plugins are executable..."
sudo chmod +x /opt/cni/bin/*
echo "✓ Permissions set"
echo ""

# Step 3: Create CNI configuration directory
echo "Step 3: Creating CNI configuration directory..."
sudo mkdir -p /etc/cni/net.d
echo "✓ Directory created"
echo ""

# Step 4: Create a basic CNI configuration for bridge networking
echo "Step 4: Creating bridge network configuration..."
sudo tee /etc/cni/net.d/10-bridge.conf > /dev/null <<'EOF'
{
  "cniVersion": "0.4.0",
  "name": "bridge",
  "type": "bridge",
  "bridge": "cni0",
  "isGateway": true,
  "ipMasq": true,
  "ipam": {
    "type": "host-local",
    "ranges": [
      [
        {
          "subnet": "10.88.0.0/16"
        }
      ]
    ],
    "routes": [
      {
        "dst": "0.0.0.0/0"
      }
    ]
  }
}
EOF

echo "✓ Bridge configuration created"
cat /etc/cni/net.d/10-bridge.conf
echo ""

# Step 5: Stop Nomad
echo "Step 5: Stopping Nomad..."
sudo pkill nomad || true
sleep 3
echo "✓ Nomad stopped"
echo ""

# Step 6: Clear Nomad data directory (dev mode)
echo "Step 6: Clearing Nomad dev data..."
sudo rm -rf /tmp/nomad-* || true
echo "✓ Data cleared"
echo ""

# Step 7: Start Nomad with proper environment
echo "Step 7: Starting Nomad..."
export CNI_PATH=/opt/cni/bin
sudo -E nomad agent -dev \
  -bind=0.0.0.0 \
  -consul-address=127.0.0.1:8500 \
  > /tmp/nomad.log 2>&1 &

echo "Waiting for Nomad to start..."
sleep 8
echo ""

# Step 8: Verify CNI detection
echo "Step 8: Verifying CNI detection..."
echo ""
echo "=== Nomad Node Attributes (CNI) ==="
nomad node status -self -verbose | grep -i cni || echo "⚠ CNI not showing in verbose output"
echo ""

echo "=== Nomad Fingerprint Check ==="
nomad node status -self -json | jq -r '.Attributes | to_entries[] | select(.key | contains("cni"))' 2>/dev/null || echo "⚠ No CNI attributes in fingerprint"
echo ""

echo "=== Checking Nomad Logs for CNI ==="
tail -100 /tmp/nomad.log | grep -i cni | head -20 || echo "⚠ No CNI messages in logs"
echo ""

# Step 9: Final check - can we run a bridge mode job?
echo "Step 9: Testing bridge mode capability..."
if nomad node status -self -json | jq -r '.Drivers.docker.Attributes["driver.docker.bridge_ip"]' 2>/dev/null | grep -q .; then
    echo "✓ Docker bridge mode detected"
else
    echo "⚠ Docker bridge mode not detected"
fi
echo ""

echo "=== Diagnostic Summary ==="
echo "If you see CNI version attributes above, Nomad has detected CNI plugins."
echo "If not, check /tmp/nomad.log for errors:"
echo "  tail -100 /tmp/nomad.log"
echo ""
echo "Try deploying now:"
echo "  task deploy:ollama"
echo ""
