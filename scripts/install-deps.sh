#!/bin/bash
# Dependency Installation Script
# Runs inside the VM to install all required dependencies

set -e

echo "=== Updating package lists ==="
sudo apt update

echo ""
echo "=== Installing base packages ==="
sudo apt install -y curl wget jq git software-properties-common

echo ""
echo "=== Installing Docker ==="
sudo apt install -y docker.io
sudo systemctl enable docker
sudo systemctl start docker
sudo usermod -aG docker ubuntu

echo ""
echo "=== Configuring Docker DNS ==="
sudo mkdir -p /etc/docker
sudo tee /etc/docker/daemon.json > /dev/null <<EOF
{
  "dns": ["8.8.8.8", "8.8.4.4"]
}
EOF
sudo systemctl restart docker
echo "Docker DNS configured to use Google DNS (8.8.8.8, 8.8.4.4)"

echo ""
echo "=== Installing HashiCorp repository ==="
wget -O- https://apt.releases.hashicorp.com/gpg | \
  sudo gpg --dearmor -o /usr/share/keyrings/hashicorp-archive-keyring.gpg

echo "deb [signed-by=/usr/share/keyrings/hashicorp-archive-keyring.gpg] https://apt.releases.hashicorp.com $(lsb_release -cs) main" | \
  sudo tee /etc/apt/sources.list.d/hashicorp.list

sudo apt update

echo ""
echo "=== Installing Vault ==="
sudo apt install -y vault

echo ""
echo "=== Installing Consul ==="
sudo apt install -y consul

echo ""
echo "=== Installing Nomad ==="
sudo apt install -y nomad

echo ""
echo "=== Installing CNI plugins for Consul Connect ==="
CNI_VERSION="v1.3.0"

# Auto-detect architecture
MACHINE_ARCH=$(uname -m)
if [ "$MACHINE_ARCH" = "aarch64" ] || [ "$MACHINE_ARCH" = "arm64" ]; then
  CNI_ARCH="arm64"
elif [ "$MACHINE_ARCH" = "x86_64" ]; then
  CNI_ARCH="amd64"
else
  echo "Unsupported architecture: $MACHINE_ARCH"
  exit 1
fi

echo "Detected architecture: $MACHINE_ARCH -> Downloading CNI for: $CNI_ARCH"
curl -L -o /tmp/cni-plugins.tgz "https://github.com/containernetworking/plugins/releases/download/${CNI_VERSION}/cni-plugins-linux-${CNI_ARCH}-${CNI_VERSION}.tgz"
sudo mkdir -p /opt/cni/bin
sudo tar -C /opt/cni/bin -xzf /tmp/cni-plugins.tgz
rm /tmp/cni-plugins.tgz
echo "CNI plugins installed to /opt/cni/bin"

echo ""
echo "=== Installing Ollama ==="
curl -fsSL https://ollama.com/install.sh | sh

echo ""
echo "=== Pulling Ollama model ==="
OLLAMA_MODEL="${OLLAMA_MODEL:-qwen2.5:0.5b}"
ollama pull "$OLLAMA_MODEL"

echo ""
echo "=== Installing Task (task runner) ==="
sudo sh -c "$(curl --location https://taskfile.dev/install.sh)" -- -d -b /usr/local/bin

echo ""
echo "=== Configuring system limits ==="
echo "* soft nofile 65536" | sudo tee -a /etc/security/limits.conf
echo "* hard nofile 65536" | sudo tee -a /etc/security/limits.conf

echo ""
echo "=== Installation Complete ==="
echo ""
echo "Installed versions:"
echo "  Vault: $(vault version | head -1)"
echo "  Consul: $(consul version | head -1)"
echo "  Nomad: $(nomad version | head -1)"
echo "  Ollama: $(ollama --version)"
echo "  Docker: $(docker --version)"
echo "  Task: $(task --version)"
echo ""
echo "NOTE: You may need to log out and back in for Docker group permissions to take effect"
