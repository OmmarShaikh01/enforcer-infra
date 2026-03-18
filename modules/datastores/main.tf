# ======================================================================================================================
# LOCALS
# ======================================================================================================================
locals {
  tier                 = "datastores"
  version              = var.enforcer_version
  deployment_namespace = var.deployment_namespace
  config_templates = {
    config_postgres = {
      hba_conf      = file("${path.module}/../../configs/postgres/pg_hba.conf")
      postgres_conf = file("${path.module}/../../configs/postgres/postgres.conf")
    }
    config_redis = {
      seed = "${path.module}/../../configs/redis/seed.sh"
    }
  }
}