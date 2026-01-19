job "executor-agent" {
  datacenters = ["dc1"]
  type        = "service"

  group "executor" {
    count = 1

    network {
      mode = "cni/consul-connect"

      port "http" {
        to = 8081
      }
    }

    service {
      name = "executor-agent"
      port = "http"

      # Consul Connect sidecar for mTLS
      connect {
        sidecar_service {
          proxy {
            # Upstream to Ollama via mTLS
            upstreams {
              destination_name = "ollama"
              local_bind_port  = 9002
            }
          }
        }
      }

      # Health check
      check {
        type     = "http"
        path     = "/health"
        interval = "10s"
        timeout  = "2s"
      }
    }

    task "executor" {
      driver = "docker"

      config {
        # Build the executor-agent image before deploying
        # docker build --build-arg AGENT_TYPE=executor -t executor-agent:latest agents/
        image = "localhost:5000/executor-agent:latest"
      }

      env {
        PORT        = "8081"
        OLLAMA_HOST = "localhost"
        OLLAMA_PORT = "9002" # Consul Connect upstream port
        OLLAMA_MODEL = "qwen2.5:0.5b"
      }

      resources {
        cpu    = 500  # 0.5 CPU
        memory = 512  # 512 MB
      }
    }
  }
}
