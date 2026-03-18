# ======================================================================================================================
# LOCALS
# ======================================================================================================================
locals {
  tier                 = "logging"
  version              = var.enforcer_version
  deployment_namespace = var.deployment_namespace
  config_templates = {
    config_alloy      = file("${path.module}/../../configs/config.alloy")
    config_prometheus = file("${path.module}/../../configs/prometheus.yaml")
    config_loki       = file("${path.module}/../../configs/loki.yaml")
    config_grafana = {
      datasources = file("${path.module}/../../configs/grafana/datasources.yaml")
      dashboards  = file("${path.module}/../../configs/grafana/dashboards.yaml")
    }
  }
}
