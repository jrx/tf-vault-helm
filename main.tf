terraform {
  backend "remote" {}
}

provider "aws" {
  region = var.aws_region
}

data "terraform_remote_state" "eks" {
  backend = "remote"
  config = {
    workspaces = {
      name = "eks-dev"
    }
    hostname     = "app.terraform.io"
    organization = "jrx"
  }
}

data "aws_eks_cluster" "cluster" {
  name = data.terraform_remote_state.eks.outputs.cluster_id
}

data "aws_eks_cluster_auth" "eks_cluster" {
  name = data.aws_eks_cluster.cluster.name
}

provider "kubernetes" {
  host                   = data.aws_eks_cluster.cluster.endpoint
  cluster_ca_certificate = base64decode(data.aws_eks_cluster.cluster.certificate_authority.0.data)
  token                  = data.aws_eks_cluster_auth.eks_cluster.token
}

resource "kubernetes_namespace" "vault" {
  metadata {
    name = var.vault-helm-namespace
  }
}

resource "kubernetes_secret" "vault-ent-license" {
  metadata {
    name      = "vault-ent-license"
    namespace = kubernetes_namespace.vault.id
  }

  data = {
    license = var.vault-ent-license
  }
}

resource "kubernetes_secret" "vault-server-tls" {
  metadata {
    name      = "vault-server-tls"
    namespace = kubernetes_namespace.vault.id
  }

  data = {
    "vault.key" = "${file("${path.module}/vault.key")}"
    "vault.crt" = "${file("${path.module}/vault.crt")}"
    "vault.ca"  = "${file("${path.module}/vault.ca")}"
  }
}

resource "kubernetes_secret" "vault-injector-tls" {
  metadata {
    name      = "vault-injector-tls"
    namespace = kubernetes_namespace.vault.id
  }

  data = {
    "tls.key" = "${file("${path.module}/vault-injector.key")}"
    "tls.crt" = "${file("${path.module}/vault-injector.crt")}"
  }
}

resource "kubernetes_secret" "eks-creds" {
  metadata {
    name      = "eks-creds"
    namespace = kubernetes_namespace.vault.id
  }

  data = {
    VAULT_AWSKMS_SEAL_KEY_ID = data.terraform_remote_state.eks.outputs.aws_kms_key
    AWS_REGION               = data.terraform_remote_state.eks.outputs.region
  }
}

provider "helm" {
  kubernetes {
    host                   = data.aws_eks_cluster.cluster.endpoint
    cluster_ca_certificate = base64decode(data.aws_eks_cluster.cluster.certificate_authority.0.data)
    token                  = data.aws_eks_cluster_auth.eks_cluster.token
  }
}

resource "helm_release" "vault" {
  name       = "vault"
  repository = "https://helm.releases.hashicorp.com"
  chart      = "vault"
  namespace  = kubernetes_namespace.vault.id
  version    = var.vault-helm-version

  values = [
    file("${path.module}/${var.vault-helm-filename}")
  ]

  set {
    name  = "server.image.tag"
    value = var.vault-image
  }

  set {
    name  = "server.ha.replicas"
    value = var.vault-replicas
  }

  set {
    name  = "injector.enabled"
    value = (var.injector == true ? true : false)
  }

  set {
    name  = "injector.certs.caBundle"
    value = base64encode(file("${path.module}/vault-injector.ca"))
  }

  set {
    name  = "csi.enabled"
    value = (var.csi == true ? true : false)
  }

  depends_on = [
    kubernetes_secret.eks-creds,
    kubernetes_secret.vault-ent-license,
  ]
}

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

data "kubernetes_service_account" "vault" {
  metadata {
    name      = "vault"
    namespace = kubernetes_namespace.vault.id
  }

  depends_on = [
    helm_release.vault
  ]
}

data "kubernetes_secret" "vault" {
  metadata {
    name      = data.kubernetes_service_account.vault.default_secret_name
    namespace = kubernetes_namespace.vault.id
  }
}