resource "helm_release" "csi" {
  name       = "csi"
  repository = "https://kubernetes-sigs.github.io/secrets-store-csi-driver/charts"
  chart      = "secrets-store-csi-driver"
  namespace  = kubernetes_namespace.vault.id
  version    = var.csi-helm-version
  count      = (var.csi == true ? 1 : 0)

  # auto-rotation
  # https://secrets-store-csi-driver.sigs.k8s.io/topics/secret-auto-rotation.html
  set {
    name  = "enableSecretRotation"
    value = true
  }

  set {
    name  = "rotationPollInterval"
    value = "10s"
  }
}