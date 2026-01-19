# Nomad Client Configuration
# Explicitly configure CNI plugin paths

client {
  enabled = true

  # CNI configuration
  cni_path = "/opt/cni/bin"
  cni_config_dir = "/etc/cni/net.d"

  # Bridge network configuration
  bridge_network_name = "nomad"
  bridge_network_subnet = "172.26.64.0/20"
}

# Plugin configuration
plugin "docker" {
  config {
    allow_privileged = true

    # Enable bridge networking
    allow_caps = ["ALL"]

    # Enable host volume mounts
    volumes {
      enabled = true
    }

    # Disable automatic image pulling - use local images
    pull_activity_timeout = "5m"
  }
}
