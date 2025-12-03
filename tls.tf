resource "tls_private_key" "vault-server" {
  algorithm = "RSA"
  rsa_bits  = 2048
}

resource "tls_cert_request" "vault-server" {
  private_key_pem = tls_private_key.vault-server.private_key_pem

  subject {
    common_name = "/O=system:nodes/CN=system:node:vault.${kubernetes_namespace.vault.id}.svc"
  }

  dns_names = [
    "vault",
    "vault.${kubernetes_namespace.vault.id}",
    "vault.${kubernetes_namespace.vault.id}.svc",
    "vault.${kubernetes_namespace.vault.id}.svc.cluster.local",
    "localhost",
  ]

  ip_addresses = [
    "127.0.0.1",
  ]
}

resource "kubernetes_certificate_signing_request_v1" "vault-server" {
  metadata {
    name = "vault-server-csr"
  }
  spec {
    usages      = ["digital signature", "key encipherment", "server auth"]
    signer_name = "beta.eks.amazonaws.com/app-serving"

    request = tls_cert_request.vault-server.cert_request_pem
  }

  auto_approve = true
}

resource "tls_private_key" "vault-injector" {
  algorithm = "RSA"
  rsa_bits  = 2048
}

resource "tls_cert_request" "vault-injector" {
  private_key_pem = tls_private_key.vault-injector.private_key_pem

  subject {
    common_name = "/O=system:nodes/CN=system:node:vault-agent-injector-svc.${kubernetes_namespace.vault.id}.svc"
  }

  dns_names = [
    "vault-agent-injector-svc",
    "vault-agent-injector-svc.${kubernetes_namespace.vault.id}",
    "vault-agent-injector-svc.${kubernetes_namespace.vault.id}.svc",
    "vault-agent-injector-svc.${kubernetes_namespace.vault.id}.svc.cluster.local",
    "localhost",
  ]
}

resource "kubernetes_certificate_signing_request_v1" "vault-injector" {
  metadata {
    name = "vault-injector-csr"
  }
  spec {
    usages      = ["digital signature", "key encipherment", "server auth"]
    signer_name = "beta.eks.amazonaws.com/app-serving"

    request = tls_cert_request.vault-injector.cert_request_pem
  }

  auto_approve = true
}