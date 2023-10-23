resource "kubernetes_namespace" "vso" {
  count = (var.vso == true ? 1 : 0)

  metadata {
    name = var.vso-helm-namespace
  }
}

resource "kubernetes_secret" "vault-cacert" {
  count = (var.vso == true ? 1 : 0)

  metadata {
    name      = "vault-cacert"
    namespace = kubernetes_namespace.vso[0].id
  }

  data = {
    "ca.crt" = base64decode(data.aws_eks_cluster.cluster.certificate_authority.0.data)
  }
}

resource "helm_release" "vso" {
  name       = "vault-secrets-operator"
  repository = "https://helm.releases.hashicorp.com"
  chart      = "vault-secrets-operator"
  namespace  = kubernetes_namespace.vso[0].id
  version    = var.vso-helm-version
  count      = (var.vso == true ? 1 : 0)

  values = [
    file("${path.module}/${var.vso-helm-filename}")
  ]
}