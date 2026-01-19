service {
  name = "planner-agent"
  id   = "planner-agent"
  port = 8080

  connect {
    sidecar_service {
      proxy {
        upstreams {
          destination_name = "executor-agent"
          local_bind_port  = 9001
        }
      }
    }
  }

  check {
    id       = "planner-health"
    name     = "Planner HTTP"
    http     = "http://localhost:8080/health"
    interval = "10s"
    timeout  = "2s"
  }
}
