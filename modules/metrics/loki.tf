# ======================================================================================================================
# RBAC
# ======================================================================================================================
resource "kubernetes_service_account_v1" "enforcer-loki-sa" {
  metadata {
    name      = "loki"
    namespace = local.deployment_namespace
    labels = {
      name    = "enforcer-loki-sa"
      tier    = local.tier
      version = local.version
    }
  }
}

resource "kubernetes_cluster_role_v1" "enforcer-loki-cr" {
  metadata {
    name = "enforcer-loki-cr"
    labels = {
      name    = "enforcer-loki-cr"
      tier    = local.tier
      version = local.version
    }
  }
}

resource "kubernetes_cluster_role_binding_v1" "enforcer-loki-binds" {
  metadata {
    name = "enforcer-loki-binds"
    labels = {
      name    = "enforcer-loki-binds"
      tier    = local.tier
      version = local.version
    }
  }
  role_ref {
    api_group = "rbac.authorization.k8s.io"
    kind      = "ClusterRole"
    name      = kubernetes_cluster_role_v1.enforcer-loki-cr.metadata[0].name
  }
  subject {
    namespace = local.deployment_namespace
    kind      = "ServiceAccount"
    name      = kubernetes_service_account_v1.enforcer-loki-sa.metadata[0].name
  }
}

# ======================================================================================================================
# NETWORK
# ======================================================================================================================
resource "kubernetes_service_v1" "enforcer-loki-srvc" {
  metadata {
    name      = "enforcer-loki-srvc"
    namespace = local.deployment_namespace
    labels = {
      name    = "enforcer-loki-srvc"
      tier    = local.tier
      version = local.version
    }
  }
  spec {
    selector = {
      name = "enforcer-loki"
    }
    port {
      name         = "frontend"
      port         = "3100"
      target_port  = "3100"
      app_protocol = "TCP"
    }
    port {
      name         = "forward"
      port         = "9096"
      target_port  = "9096"
      app_protocol = "TCP"
    }
  }
}

# ======================================================================================================================
# STORAGE
# ======================================================================================================================
resource "kubernetes_persistent_volume_claim_v1" "enforcer-loki-pvc" {
  metadata {
    name      = "enforcer-loki-pvc"
    namespace = local.deployment_namespace
    labels = {
      name    = "enforcer-loki-pvc"
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

resource "kubernetes_config_map_v1" "enforcer-loki-config" {
  metadata {
    name      = "enforcer-loki-config"
    namespace = local.deployment_namespace
    labels = {
      name    = "enforcer-loki-config"
      tier    = local.tier
      version = local.version
    }
  }
  data = {
    "loki.yml" = local.config_templates.config_loki
  }
}

# ======================================================================================================================
# DEPLOYMENT
# ======================================================================================================================
resource "kubernetes_daemon_set_v1" "enforcer-loki" {
  metadata {
    name      = kubernetes_service_v1.enforcer-loki-srvc.spec[0].selector.name
    namespace = local.deployment_namespace
    labels = {
      name        = kubernetes_service_v1.enforcer-loki-srvc.spec[0].selector.name
      tier        = local.tier
      version     = local.version
      config_hash = md5(local.config_templates.config_loki)
    }
  }
  spec {
    selector {
      match_labels = {
        name = kubernetes_service_v1.enforcer-loki-srvc.spec[0].selector.name
      }
    }
    template {
      metadata {
        labels = {
          name    = kubernetes_service_v1.enforcer-loki-srvc.spec[0].selector.name
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
        service_account_name             = kubernetes_service_account_v1.enforcer-loki-sa.metadata[0].name
        security_context {
          fs_group        = "10001"
          run_as_user     = "10001"
          run_as_group    = "10001"
          run_as_non_root = true
        }
        container {
          name  = kubernetes_service_v1.enforcer-loki-srvc.spec[0].selector.name
          image = var.images.image_loki
          args = [
            "-config.file=/etc/loki/loki.yml",
          ]
          port {
            name           = kubernetes_service_v1.enforcer-loki-srvc.spec[0].port[0].name
            container_port = kubernetes_service_v1.enforcer-loki-srvc.spec[0].port[0].port
            protocol       = kubernetes_service_v1.enforcer-loki-srvc.spec[0].port[0].app_protocol
          }
          port {
            name           = kubernetes_service_v1.enforcer-loki-srvc.spec[0].port[1].name
            container_port = kubernetes_service_v1.enforcer-loki-srvc.spec[0].port[1].port
            protocol       = kubernetes_service_v1.enforcer-loki-srvc.spec[0].port[1].app_protocol
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
          volume_mount {
            name       = "config"
            mount_path = "/etc/loki/loki.yml"
            sub_path   = "loki.yml"
          }
          volume_mount {
            name       = "storage"
            mount_path = "/loki"
          }
        }
        volume {
          name = "config"
          config_map {
            name = kubernetes_config_map_v1.enforcer-loki-config.metadata[0].name
          }
        }
        volume {
          name = "storage"
          persistent_volume_claim {
            claim_name = "enforcer-loki-pvc"
          }
        }
      }
    }
  }
}
