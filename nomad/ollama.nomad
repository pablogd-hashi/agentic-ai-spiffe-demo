job "ollama" {
  datacenters = ["dc1"]
  type        = "service"

  group "ollama" {
    count = 1

    network {
      mode = "cni/consul-connect"

      port "http" {
        static = 11434
        to     = 11434
      }
    }

    service {
      name = "ollama"
      port = "http"

      # Consul Connect sidecar for mTLS
      connect {
        sidecar_service {}
      }

      # Health check
      check {
        type     = "http"
        path     = "/"
        interval = "10s"
        timeout  = "2s"
      }
    }

    task "ollama" {
      driver = "docker"

      config {
        image = "ollama/ollama:latest"

        # Mount a volume for Ollama models
        volumes = [
          "/tmp/ollama:/root/.ollama"
        ]

        args = [
          "serve"
        ]
      }

      env {
        OLLAMA_HOST = "0.0.0.0:11434"
      }

      resources {
        cpu    = 1000 # 1 CPU
        memory = 2048 # 2GB RAM
      }
    }
  }
}
