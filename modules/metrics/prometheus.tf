# ======================================================================================================================
# RBAC
# ======================================================================================================================
resource "kubernetes_service_account_v1" "enforcer-prometheus-sa" {
  metadata {
    name      = "prometheus"
    namespace = local.deployment_namespace
    labels = {
      name    = "enforcer-prometheus-sa"
      tier    = local.tier
      version = local.version
    }
  }
}

resource "kubernetes_cluster_role_v1" "enforcer-prometheus-cr" {
  metadata {
    name = "enforcer-prometheus-cr"
    labels = {
      name    = "enforcer-prometheus-cr"
      tier    = local.tier
      version = local.version
    }
  }
  rule {
    api_groups = [""]
    verbs      = ["get", "list", "watch"]
    resources  = ["nodes", "nodes/proxy", "nodes/metrics", "services", "endpoints", "pods"]
  }
  rule {
    api_groups = ["extensions", "networking.k8s.io"]
    verbs      = ["get", "list", "watch"]
    resources  = ["ingresses"]
  }
  rule {
    non_resource_urls = ["/metrics", "/metrics/cadvisor"]
    verbs             = ["get"]
  }
}

resource "kubernetes_cluster_role_binding_v1" "enforcer-prometheus-binds" {
  metadata {
    name = "enforcer-prometheus-binds"
    labels = {
      name    = "enforcer-prometheus-binds"
      tier    = local.tier
      version = local.version
    }
  }
  role_ref {
    api_group = "rbac.authorization.k8s.io"
    kind      = "ClusterRole"
    name      = kubernetes_cluster_role_v1.enforcer-prometheus-cr.metadata[0].name
  }
  subject {
    namespace = local.deployment_namespace
    kind      = "ServiceAccount"
    name      = kubernetes_service_account_v1.enforcer-prometheus-sa.metadata[0].name
  }
}

# ======================================================================================================================
# NETWORK
# ======================================================================================================================
resource "kubernetes_service_v1" "enforcer-prometheus-srvc" {
  metadata {
    name      = "enforcer-prometheus-srvc"
    namespace = local.deployment_namespace
    labels = {
      name    = "enforcer-prometheus-srvc"
      tier    = local.tier
      version = local.version
    }
  }
  spec {
    selector = {
      name = "enforcer-prometheus"
    }
    port {
      name         = "metrics"
      port         = "9090"
      target_port  = "9090"
      app_protocol = "TCP"
    }
  }
}

# ======================================================================================================================
# STORAGE
# ======================================================================================================================
resource "kubernetes_persistent_volume_claim_v1" "enforcer-prometheus-pvc" {
  metadata {
    name      = "enforcer-prometheus-pvc"
    namespace = local.deployment_namespace
    labels = {
      name    = "enforcer-prometheus-pvc"
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

resource "kubernetes_config_map_v1" "enforcer-prometheus-config" {
  metadata {
    name      = "enforcer-prometheus-config"
    namespace = var.deployment_namespace
    labels = {
      name    = "enforcer-prometheus-config"
      tier    = local.tier
      version = local.version
    }
  }
  data = {
    "prometheus.yml" = local.config_templates.config_prometheus
  }
}

# ======================================================================================================================
# DEPLOYMENT
# ======================================================================================================================
resource "kubernetes_daemon_set_v1" "enforcer-prometheus" {
  metadata {
    name      = kubernetes_service_v1.enforcer-prometheus-srvc.spec[0].selector.name
    namespace = var.deployment_namespace
    labels = {
      name        = kubernetes_service_v1.enforcer-prometheus-srvc.spec[0].selector.name
      tier        = local.tier
      version     = local.version
      config_hash = md5(local.config_templates.config_prometheus)
    }
  }
  spec {
    selector {
      match_labels = {
        name = kubernetes_service_v1.enforcer-prometheus-srvc.spec[0].selector.name
      }
    }
    template {
      metadata {
        labels = {
          name    = kubernetes_service_v1.enforcer-prometheus-srvc.spec[0].selector.name
          tier    = local.tier
          version = local.version
        }
      }
      spec {
        termination_grace_period_seconds = 30
        service_account_name             = "prometheus"
        security_context {
          fs_group        = "65534"
          run_as_user     = "65534"
          run_as_non_root = true
        }
        volume {
          name = "config"
          config_map {
            name = kubernetes_config_map_v1.enforcer-prometheus-config.metadata[0].name
          }
        }
        volume {
          name = "storage"
          persistent_volume_claim {
            claim_name = "enforcer-prometheus-pvc"
          }
        }
        container {
          name  = kubernetes_service_v1.enforcer-prometheus-srvc.spec[0].selector.name
          image = var.images.image_prometheus
          args = [
            "--config.file=/etc/prometheus/prometheus.yml",
            "--storage.tsdb.path=/prometheus",
            "--storage.tsdb.retention.time=15d",
            "--web.console.libraries=/usr/share/prometheus/console_libraries",
            "--web.console.templates=/usr/share/prometheus/consoles",
            "--web.enable-lifecycle"
          ]
          port {
            name           = kubernetes_service_v1.enforcer-prometheus-srvc.spec[0].port[0].name
            container_port = kubernetes_service_v1.enforcer-prometheus-srvc.spec[0].port[0].port
            protocol       = kubernetes_service_v1.enforcer-prometheus-srvc.spec[0].port[0].app_protocol
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
            mount_path = "/etc/prometheus/prometheus.yml"
            sub_path   = "prometheus.yml"
          }
          volume_mount {
            name       = "storage"
            mount_path = "/prometheus"
          }
        }
      }
    }
  }
}
