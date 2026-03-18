# ======================================================================================================================
# RBAC
# ======================================================================================================================
resource "kubernetes_service_account_v1" "enforcer-grafana-sa" {
  metadata {
    name      = "grafana"
    namespace = var.deployment_namespace
    labels = {
      name    = "enforcer-grafana-sa"
      tier    = local.tier
      version = local.version
    }
  }
}

resource "kubernetes_cluster_role_v1" "enforcer-grafana-cr" {
  metadata {
    name = "enforcer-grafana-cr"
    labels = {
      name    = "enforcer-grafana-cr"
      tier    = local.tier
      version = local.version
    }
  }
}

resource "kubernetes_cluster_role_binding_v1" "enforcer-grafana-binds" {
  metadata {
    name = "enforcer-grafana-binds"
    labels = {
      name    = "enforcer-grafana-binds"
      tier    = local.tier
      version = local.version
    }
  }
  role_ref {
    api_group = "rbac.authorization.k8s.io"
    kind      = "ClusterRole"
    name      = kubernetes_cluster_role_v1.enforcer-grafana-cr.metadata[0].name
  }
  subject {
    namespace = var.deployment_namespace
    kind      = "ServiceAccount"
    name      = kubernetes_service_account_v1.enforcer-grafana-sa.metadata[0].name
  }
}

# ======================================================================================================================
# NETWORK
# ======================================================================================================================
resource "kubernetes_service_v1" "enforcer-grafana-srvc" {
  metadata {
    name      = "enforcer-grafana-srvc"
    namespace = var.deployment_namespace
    labels = {
      name    = "enforcer-grafana-srvc"
      tier    = local.tier
      version = local.version
    }
  }
  spec {
    selector = {
      name = "enforcer-grafana"
    }
    port {
      name         = "metrics"
      port         = "3000"
      target_port  = "3000"
      app_protocol = "TCP"
    }
  }
}

# ======================================================================================================================
# STORAGE
# ======================================================================================================================
resource "kubernetes_persistent_volume_claim_v1" "enforcer-grafana-pvc" {
  metadata {
    name      = "enforcer-grafana-pvc"
    namespace = var.deployment_namespace
    labels = {
      name    = "enforcer-grafana-pvc"
      tier    = local.tier
      version = local.version
    }
  }
  spec {
    access_modes = ["ReadWriteOnce"]
    resources {
      requests = {
        storage = "5Gi"
      }
    }
  }
}

resource "kubernetes_config_map_v1" "enforcer-grafana-config" {
  metadata {
    name      = "enforcer-grafana-config"
    namespace = var.deployment_namespace
    labels = {
      name    = "enforcer-grafana-config"
      tier    = local.tier
      version = local.version
    }
  }
  data = {
    "datasources.yaml" = local.config_templates.config_grafana.datasources
    "dashboards.yaml"  = local.config_templates.config_grafana.dashboards
  }
}

resource "kubernetes_secret_v1" "enforcer-grafana-secrets" {
  metadata {
    name      = "enforcer-grafana-secrets"
    namespace = var.deployment_namespace
    labels = {
      name    = "enforcer-grafana-secrets"
      tier    = local.tier
      version = local.version
    }
  }
  immutable = true
  data = {
    GRAFANA_USER     = var.enforcer_secrets.grafana.username
    GRAFANA_PASSWORD = var.enforcer_secrets.grafana.password
  }
}

# ======================================================================================================================
# DEPLOYMENT
# ======================================================================================================================
resource "kubernetes_daemon_set_v1" "enforcer-grafana" {
  metadata {
    name      = kubernetes_service_v1.enforcer-grafana-srvc.spec[0].selector.name
    namespace = var.deployment_namespace
    labels = {
      name        = kubernetes_service_v1.enforcer-grafana-srvc.spec[0].selector.name
      tier        = local.tier
      version     = local.version
      config_hash = md5("${local.config_templates.config_grafana.dashboards}${local.config_templates.config_grafana.dashboards}")
    }
  }
  spec {
    selector {
      match_labels = {
        name = kubernetes_service_v1.enforcer-grafana-srvc.spec[0].selector.name
      }
    }
    template {
      metadata {
        labels = {
          name    = kubernetes_service_v1.enforcer-grafana-srvc.spec[0].selector.name
          tier    = local.tier
          version = local.version
        }
        annotations = {
          "prometheus.io/port"   = "24231"
          "prometheus.io/scrape" = "true"
        }
      }
      spec {
        termination_grace_period_seconds = 30
        service_account_name             = kubernetes_service_account_v1.enforcer-grafana-sa.metadata[0].name
        security_context {
          fs_group        = "472"
          run_as_user     = "472"
          run_as_non_root = true
        }
        container {
          name  = kubernetes_service_v1.enforcer-grafana-srvc.spec[0].selector.name
          image = var.images.image_grafana
          port {
            name           = kubernetes_service_v1.enforcer-grafana-srvc.spec[0].port[0].name
            container_port = kubernetes_service_v1.enforcer-grafana-srvc.spec[0].port[0].port
            protocol       = kubernetes_service_v1.enforcer-grafana-srvc.spec[0].port[0].app_protocol
          }
          resources {
            limits = {
              cpu    = "500m"
              memory = "500Mi"
            }
            requests = {
              cpu    = "100m"
              memory = "200Mi"
            }
          }
          env {
            name = "GF_SECURITY_ADMIN_USER"
            value_from {
              secret_key_ref {
                name = kubernetes_secret_v1.enforcer-grafana-secrets.metadata[0].name
                key  = "GRAFANA_USER"
              }
            }
          }
          env {
            name = "GF_SECURITY_ADMIN_PASSWORD"
            value_from {
              secret_key_ref {
                name = kubernetes_secret_v1.enforcer-grafana-secrets.metadata[0].name
                key  = "GRAFANA_PASSWORD"
              }
            }
          }
          env {
            name  = "GF_PATHS_PROVISIONING"
            value = "/etc/grafana/provisioning"
          }
          env {
            name  = "GF_SERVER_ROOT_URL"
            value = "http://localhost:3000"
          }
          env {
            name  = "GF_FEATURE_TOGGLES_ENABLE"
            value = "ngalert"
          }
          env {
            name  = "GF_ANALYTICS_REPORTING_ENABLED"
            value = "false"
          }
          volume_mount {
            name       = "config"
            mount_path = "/etc/grafana/provisioning/datasources/datasources.yaml"
            sub_path   = "datasources.yaml"
          }
          volume_mount {
            name       = "config"
            mount_path = "/etc/grafana/provisioning/datasources/dashboards.yaml"
            sub_path   = "dashboards.yaml"
          }
          volume_mount {
            name       = "storage"
            mount_path = "/var/lib/grafana"
          }
        }
        volume {
          name = "config"
          config_map {
            name = kubernetes_config_map_v1.enforcer-grafana-config.metadata[0].name
          }
        }
        volume {
          name = "storage"
          persistent_volume_claim {
            claim_name = "enforcer-grafana-pvc"
          }
        }
      }
    }
  }
}
