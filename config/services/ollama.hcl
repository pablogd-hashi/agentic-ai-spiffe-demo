service {
  name = "ollama"
  id   = "ollama"
  port = 11434

  connect {
    sidecar_service {}
  }

  check {
    id       = "ollama-health"
    name     = "Ollama HTTP"
    http     = "http://localhost:11434/"
    interval = "10s"
    timeout  = "2s"
  }
}
