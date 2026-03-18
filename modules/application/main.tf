# ======================================================================================================================
# LOCALS
# ======================================================================================================================
locals {
  tier                 = "application"
  version              = var.enforcer_version
  deployment_namespace = var.deployment_namespace
  environment          = var.environemnt
}