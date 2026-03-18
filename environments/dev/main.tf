terraform {
  required_version = ">= 1.5.0"

  required_providers {
    kubernetes = {
      source  = "hashicorp/kubernetes"
      version = "3.0.1"
    }
    helm = {
      source  = "hashicorp/helm"
      version = "3.1.1"
    }
    http = {
      source  = "hashicorp/http"
      version = "3.5.0"
    }
    kubectl = {
      source  = "gavinbunney/kubectl"
      version = "1.19.0"
    }
  }
}

# ======================================================================================================================
# Providers
# ======================================================================================================================
provider "kubernetes" {
  config_path    = var.kube_config_path
  config_context = var.kube_context
}

provider "helm" {
  kubernetes = {
    config_path = var.kube_config_path
  }
}

# ======================================================================================================================
# Locals
# ======================================================================================================================
locals {
  # Metrics
  image_alloy      = format("%s/%s:%s", "docker.io", "grafana/alloy", "v1.14.0")
  image_loki       = format("%s/%s:%s", "docker.io", "grafana/loki", "3.5.12")
  image_grafana    = format("%s/%s:%s", "docker.io", "grafana/grafana", "12.3.5")
  image_prometheus = format("%s/%s:%s", "docker.io", "prom/prometheus", "main-distroless")

  # Datastores
  image_postgres_lb = format("%s/%s:%s", "docker.io", "edoburu/pgbouncer", "v1.25.1-p0")
  image_postgres    = format("%s/%s:%s", "docker.io", "postgres", "18.3-alpine")
  image_redis       = format("%s/%s:%s", "docker.io", "redis", "8.6")

  # Applications
  image_ui_frontend = format("%s/%s:%s", var.repository_url, "enforcer-ui", "0.1.0")
  image_api_backend = format("%s/%s:%s", var.repository_url, "enforcer-api", "0.1.0")
}

# ======================================================================================================================
# Resources
# ======================================================================================================================
resource "kubernetes_namespace_v1" "enforcer_global_namespace" {
  metadata {
    name = var.deployment_namespace
  }
}

resource "helm_release" "enforcer-crd-gateway-fabric" {
  depends_on = [
    kubernetes_namespace_v1.enforcer_global_namespace
  ]

  name       = "enforcer-crd-gateway-fabric"
  namespace  = var.deployment_namespace
  repository = "oci://ghcr.io/nginx/charts"
  chart      = "nginx-gateway-fabric"
}

# ======================================================================================================================
# Modules
# ======================================================================================================================
module "enforcer_metrics" {
  depends_on = [
    kubernetes_namespace_v1.enforcer_global_namespace,
    helm_release.enforcer-crd-gateway-fabric
  ]
  source               = "../../modules/metrics"
  deployment_namespace = var.deployment_namespace
  enforcer_version     = var.enforcer_version
  enforcer_secrets     = var.enforcer_secrets
  environment          = var.environment
  images = {
    image_alloy      = local.image_alloy
    image_loki       = local.image_loki
    image_grafana    = local.image_grafana
    image_prometheus = local.image_prometheus
  }
}

module "enforcer_datastores" {
  source               = "../../modules/datastores"
  deployment_namespace = var.deployment_namespace
  enforcer_version     = var.enforcer_version
  enforcer_secrets     = var.enforcer_secrets
  environemnt          = var.environment
  images = {
    image_postgres    = local.image_postgres
    image_postgres_lb = local.image_postgres_lb
    image_redis       = local.image_redis
  }
  depends_on = [
    kubernetes_namespace_v1.enforcer_global_namespace,
    helm_release.enforcer-crd-gateway-fabric,
    module.enforcer_metrics
  ]
}

# module "enforcer_application" {
#   source               = "./application"
#   deployment_namespace = var.deployment_namespace
#   enforcer_version     = var.enforcer_version
#   enforcer_secrets     = var.enforcer_secrets
#   environemnt          = var.environment
#   images = {
#     image_ui_frontend = local.image_ui_frontend
#     image_api_backend = local.image_api_backend
#   }
#   depends_on = [
#     kubernetes_namespace_v1.enforcer_global_namespace,
#     helm_release.enforcer_crd_gateway_fabric,
#     module.enforcer_datastores
#   ]
# }

