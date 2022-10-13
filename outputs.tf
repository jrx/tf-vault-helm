output "issuer" {
  value = data.aws_eks_cluster.cluster.identity[0].oidc[0].issuer
}

output "token" {
  value     = data.kubernetes_secret.vault.data["token"]
  sensitive = true
}

output "ca" {
  value     = data.kubernetes_secret.vault.data["ca.crt"]
  sensitive = true
}