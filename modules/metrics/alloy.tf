# ======================================================================================================================
# RBAC
# ======================================================================================================================
resource "kubernetes_service_account_v1" "enforcer-alloy-sa" {
  metadata {
    name      = "alloy"
    namespace = local.deployment_namespace
    labels = {
      tier    = local.tier
      version = local.version
    }
  }
}

resource "kubernetes_cluster_role_v1" "enforcer-alloy-cr" {
  metadata {
    name = "enforcer-alloy-cr"
    labels = {
      name    = "enforcer-alloy-cr"
      tier    = local.tier
      version = local.version
    }
  }
  rule {
    verbs      = ["get", "list", "watch"]
    api_groups = [""]
    resources = [
      "pods", "namespaces", "nodes", "nodes/proxy", "pods/log"
    ]
  }
}

resource "kubernetes_cluster_role_binding_v1" "enforcer-alloy-binds" {
  metadata {
    name = "enforcer-alloy-binds"
    labels = {
      name    = "enforcer-alloy-binds"
      tier    = local.tier
      version = local.version
    }
  }
  role_ref {
    api_group = "rbac.authorization.k8s.io"
    kind      = "ClusterRole"
    name      = kubernetes_cluster_role_v1.enforcer-alloy-cr.metadata[0].name
  }
  subject {
    namespace = local.deployment_namespace
    kind      = "ServiceAccount"
    name      = kubernetes_service_account_v1.enforcer-alloy-sa.metadata[0].name
  }
}

# ======================================================================================================================
# NETWORK
# ======================================================================================================================
resource "kubernetes_service_v1" "enforcer-alloy-srvc" {
  metadata {
    name      = "enforcer-alloy-srvc"
    namespace = local.deployment_namespace
    labels = {
      tier    = local.tier
      version = local.version
    }
  }
  spec {
    selector = {
      name = "enforcer-alloy"
    }
    port {
      name         = "monitor"
      port         = "12345"
      target_port  = "12345"
      app_protocol = "TCP"
    }
  }
}

# ======================================================================================================================
# STORAGE
# ======================================================================================================================
resource "kubernetes_config_map_v1" "enforcer-alloy-config" {
  metadata {
    name      = "enforcer-alloy-config"
    namespace = local.deployment_namespace
    labels = {
      name    = "enforcer-alloy-config"
      tier    = local.tier
      version = local.version
    }
  }
  data = {
    "config.alloy" = local.config_templates.config_alloy
  }
}

# ======================================================================================================================
# DEPLOYMENT
# ======================================================================================================================
resource "kubernetes_daemon_set_v1" "enforcer-alloy" {
  metadata {
    name      = kubernetes_service_v1.enforcer-alloy-srvc.spec[0].selector.name
    namespace = local.deployment_namespace
    labels = {
      name        = kubernetes_service_v1.enforcer-alloy-srvc.spec[0].selector.name
      tier        = local.tier
      version     = local.version
      config_hash = md5(local.config_templates.config_alloy)
    }
  }
  spec {
    selector {
      match_labels = {
        name = kubernetes_service_v1.enforcer-alloy-srvc.spec[0].selector.name
      }
    }
    template {
      metadata {
        labels = {
          name    = kubernetes_service_v1.enforcer-alloy-srvc.spec[0].selector.name
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
        service_account_name             = kubernetes_service_account_v1.enforcer-alloy-sa.metadata[0].name
        volume {
          name = "config"
          config_map {
            name = kubernetes_config_map_v1.enforcer-alloy-config.metadata[0].name
          }
        }
        volume {
          name = "var-logs"
          host_path {
            path = "/var/log"
          }
        }
        volume {
          name = "var-containers"
          host_path {
            path = "/var/lib/docker/containers"
          }
        }
        volume {
          name = "machine-id"
          host_path {
            path = "/etc/machine-id"
            type = "File"
          }
        }
        container {
          name  = kubernetes_service_v1.enforcer-alloy-srvc.spec[0].selector.name
          image = var.images.image_alloy
          args = [
            "run", "/etc/alloy/config.alloy", "--storage.path=/var/lib/alloy/data",
            "--server.http.listen-addr=0.0.0.0:12345"
          ]
          port {
            name           = kubernetes_service_v1.enforcer-alloy-srvc.spec[0].port[0].name
            container_port = kubernetes_service_v1.enforcer-alloy-srvc.spec[0].port[0].port
            protocol       = kubernetes_service_v1.enforcer-alloy-srvc.spec[0].port[0].app_protocol
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
            mount_path = "/etc/alloy/config.alloy"
            sub_path   = "config.alloy"
          }
          volume_mount {
            name       = "var-logs"
            mount_path = "/var/lib/alloy/data"
          }
          volume_mount {
            name       = "var-containers"
            mount_path = "/var/lib/docker/containers"
            read_only  = true
          }
          volume_mount {
            name       = "machine-id"
            mount_path = "/etc/machine-id"
            read_only  = true
          }
        }
      }
    }
  }
}
