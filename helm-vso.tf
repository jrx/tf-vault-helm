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

  set {
    name  = "csi.enabled"
    value = (var.vso-csi == true ? true : false)
  }
}

resource "kubernetes_role" "vault_secrets_operator_csi_role" {
  count = (var.vso == true ? 1 : 0)
  metadata {
    name      = "vault-secrets-operator-csi-role"
    namespace = kubernetes_namespace.vso[0].id
  }

  rule {
    api_groups     = [""]
    resources      = ["secrets"]
    verbs          = ["get"]
    resource_names = ["vault-cacert"]
  }
}

resource "kubernetes_role_binding" "vault_secrets_operator_csi_rolebinding" {
  count = (var.vso == true ? 1 : 0)
  metadata {
    name      = "vault-secrets-operator-csi-rolebinding"
    namespace = kubernetes_namespace.vso[0].id
  }

  role_ref {
    api_group = "rbac.authorization.k8s.io"
    kind      = "Role"
    name      = kubernetes_role.vault_secrets_operator_csi_role[0].metadata[0].name
  }

  subject {
    kind      = "ServiceAccount"
    name      = "vault-secrets-operator-csi"
    namespace = kubernetes_namespace.vso[0].id
  }
}