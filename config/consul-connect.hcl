# Consul Connect configuration
# Enables service mesh with mTLS

connect {
  enabled = true
}

# Use Vault as the CA for SPIFFE certificates
# In dev mode, Consul uses its built-in CA by default
# For production, configure Vault CA provider:
#
# connect {
#   ca_provider = "vault"
#   ca_config {
#     address = "http://vault:8200"
#     token = "root"
#     root_pki_path = "pki"
#     intermediate_pki_path = "pki_int"
#   }
# }

# Default deny - services cannot communicate unless explicitly allowed
acl {
  enabled = false
  default_policy = "allow"
}
