variable "aws_region" {
  default = "eu-north-1"
}
variable "vault-ent-license" {}
variable "injector" {
  type        = bool
  description = "Deploy the Vault Agent Injector"
  default     = false
}
variable "csi" {
  type        = bool
  description = "Deploy the CSI driver"
  default     = false
}