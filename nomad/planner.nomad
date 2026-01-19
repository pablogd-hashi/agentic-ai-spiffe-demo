job "planner-agent" {
  datacenters = ["dc1"]
  type        = "service"

  group "planner" {
    count = 1

    network {
      mode = "cni/consul-connect"

      port "http" {
        static = 8080
        to     = 8080
      }
    }

    service {
      name = "planner-agent"
      port = "http"

      # Consul Connect sidecar for mTLS
      connect {
        sidecar_service {
          proxy {
            # Upstream to executor-agent via mTLS
            upstreams {
              destination_name = "executor-agent"
              local_bind_port  = 9001
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

    task "planner" {
      driver = "docker"

      config {
        # Build the planner-agent image before deploying
        # docker build --build-arg AGENT_TYPE=planner -t planner-agent:latest agents/
        image = "localhost:5000/planner-agent:latest"
        ports = ["http"]
      }

      env {
        PORT          = "8080"
        EXECUTOR_HOST = "localhost"
        EXECUTOR_PORT = "9001" # Consul Connect upstream port
      }

      resources {
        cpu    = 500  # 0.5 CPU
        memory = 512  # 512 MB
      }
    }
  }
}
