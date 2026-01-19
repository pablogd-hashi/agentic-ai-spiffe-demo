service {
  name = "executor-agent"
  id   = "executor-agent"
  port = 8081

  connect {
    sidecar_service {
      proxy {
        upstreams {
          destination_name = "ollama"
          local_bind_port  = 9002
        }
      }
    }
  }

  check {
    id       = "executor-health"
    name     = "Executor HTTP"
    http     = "http://localhost:8081/health"
    interval = "10s"
    timeout  = "2s"
  }
}
