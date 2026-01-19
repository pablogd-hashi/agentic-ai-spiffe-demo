#!/bin/bash
# Install CNI Plugins for Consul Connect
# This is required for bridge networking mode

set -e

echo "=== Installing CNI Plugins ==="

CNI_VERSION="v1.3.0"

# Auto-detect architecture
MACHINE_ARCH=$(uname -m)
if [ "$MACHINE_ARCH" = "aarch64" ] || [ "$MACHINE_ARCH" = "arm64" ]; then
  ARCH="arm64"
elif [ "$MACHINE_ARCH" = "x86_64" ]; then
  ARCH="amd64"
else
  echo "Unsupported architecture: $MACHINE_ARCH"
  exit 1
fi

echo "Detected architecture: $MACHINE_ARCH -> Using CNI plugins for: $ARCH"
echo "Downloading CNI plugins ${CNI_VERSION} for ${ARCH}..."
curl -L -o /tmp/cni-plugins.tgz \
  "https://github.com/containernetworking/plugins/releases/download/${CNI_VERSION}/cni-plugins-linux-${ARCH}-${CNI_VERSION}.tgz"

echo "Creating CNI directory..."
sudo mkdir -p /opt/cni/bin

echo "Extracting CNI plugins..."
sudo tar -C /opt/cni/bin -xzf /tmp/cni-plugins.tgz

echo "Cleaning up..."
rm /tmp/cni-plugins.tgz

echo ""
echo "=== CNI Plugins Installed ==="
ls -lh /opt/cni/bin/ | head -20

echo ""
echo "=== Restarting Nomad to detect CNI plugins ==="
sudo pkill nomad || true
sleep 3

# Start Nomad
cd "$(dirname "$0")/.."
if command -v task &> /dev/null; then
    task nomad:start
else
    # Get the bind IP
    CONSUL_BIND_IP=$(ip -4 addr show | grep -oP '(?<=inet\s)\d+(\.\d+){3}' | grep -v '127.0.0.1' | head -n 1)
    sudo nomad agent -dev -bind=$CONSUL_BIND_IP -consul-address=127.0.0.1:8500 > /tmp/nomad.log 2>&1 &
fi

sleep 5

echo ""
echo "=== Verifying CNI is available ==="
nomad node status -self | grep -i cni || echo "CNI version info not shown (check manually)"

echo ""
echo "✓ CNI plugins installed successfully"
echo ""
echo "You can now deploy jobs with bridge networking:"
echo "  task deploy:all"
