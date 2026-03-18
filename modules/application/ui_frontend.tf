# ======================================================================================================================
# RBAC
# ======================================================================================================================
resource "kubernetes_service_account_v1" "enforcer_ui_frontend_sa" {
  metadata {
    name      = "ui_frontend"
    namespace = local.deployment_namespace
    labels = {
      name    = "enforcer_ui_frontend_sa"
      tier    = local.tier
      version = local.version
    }
  }
}

resource "kubernetes_cluster_role_v1" "enforcer_ui_frontend_cr" {
  metadata {
    name = "enforcer_ui_frontend_cr"
    labels = {
      name    = "enforcer_ui_frontend_cr"
      tier    = local.tier
      version = local.version
    }
  }
}

resource "kubernetes_cluster_role_binding_v1" "enforcer_ui_frontend_binds" {
  metadata {
    name = "enforcer_ui_frontend_binds"
    labels = {
      name    = "enforcer_ui_frontend_binds"
      tier    = local.tier
      version = local.version
    }
  }
  role_ref {
    api_group = "rbac.authorization.k8s.io"
    kind      = "ClusterRole"
    name      = "enforcer_ui_frontend_cr"
  }
  subject {
    kind      = "ServiceAccount"
    name      = "ui_frontend"
    namespace = local.deployment_namespace
  }
}

# ======================================================================================================================
# NETWORK
# ======================================================================================================================
resource "kubernetes_service_v1" "enforcer_ui_frontend_srvc" {
  metadata {
    name      = "enforcer_ui_frontend_srvc"
    namespace = local.deployment_namespace
    labels = {
      name    = "enforcer_ui_frontend_srvc"
      tier    = local.tier
      version = local.version
    }
  }
  spec {
    selector = {
      name = "enforcer_ui_frontend"
    }
    port {
      name         = "listner"
      port         = "3000"
      target_port  = "3000"
      app_protocol = "TCP"
    }
  }
}

# ======================================================================================================================
# STORAGE
# ======================================================================================================================
resource "kubernetes_secret_v1" "enforcer_ui_frontend_secrets" {
  metadata {
    name      = "enforcer_ui_frontend_secrets"
    namespace = local.deployment_namespace
    labels = {
      name    = "enforcer_ui_frontend_secrets"
      tier    = local.tier
      version = local.version
    }
  }
  immutable = true
  data = {
    REDIS_USER     = var.enforcer_secrets.redis.username
    REDIS_PASSWORD = var.enforcer_secrets.redis.password
    REDIS_DB       = var.enforcer_secrets.redis.name
  }
}

# ======================================================================================================================
# DEPLOYMENT
# ======================================================================================================================
resource "kubernetes_deployment_v1" "enforcer_ui_frontend" {
  depends_on = [
    kubernetes_deployment_v1.enforcer_api_backend
  ]

  metadata {
    name      = kubernetes_service_v1.enforcer_ui_frontend_srvc.spec[0].selector.name
    namespace = local.deployment_namespace
    labels = {
      name    = kubernetes_service_v1.enforcer_ui_frontend_srvc.spec[0].selector.name
      tier    = local.tier
      version = local.version
    }
  }

  spec {
    selector {
      match_labels = {
        name = kubernetes_service_v1.enforcer_ui_frontend_srvc.spec[0].selector.name
      }
    }
    template {
      metadata {
        labels = {
          name = kubernetes_service_v1.enforcer_ui_frontend_srvc.spec[0].selector.name
        }
      }
      spec {
        termination_grace_period_seconds = 30
        service_account_name             = kubernetes_service_account_v1.enforcer_ui_frontend_sa.metadata[0].name
        security_context {
          run_as_non_root = true
          run_as_user     = "120"
          run_as_group    = "120"
        }
        container {
          name              = kubernetes_service_v1.enforcer_ui_frontend_srvc.spec[0].selector.name
          image             = var.images.image_ui_frontend
          image_pull_policy = "Always"
          command           = ["/entrypoint.sh"]
          port {
            name           = kubernetes_service_v1.enforcer_ui_frontend_srvc.spec[0].port[0].name
            container_port = kubernetes_service_v1.enforcer_ui_frontend_srvc.spec[0].port[0].target_port
            protocol       = kubernetes_service_v1.enforcer_ui_frontend_srvc.spec[0].port[0].app_protocol
          }
          env {
            name  = "ENFORCER_VAULT_HOST"
            value = "enforcer_redis_srvc"
          }
          env {
            name  = "ENFORCER_VAULT_PORT"
            value = "6379"
          }
          env {
            name = "ENFORCER_VAULT_USERNAME"
            value_from {
              secret_key_ref {
                name = "enforcer_api_backend_secrets"
                key  = "REDIS_USER"
              }
            }
          }
          env {
            name = "ENFORCER_VAULT_PASSWORD"
            value_from {
              secret_key_ref {
                name = "enforcer_api_backend_secrets"
                key  = "REDIS_PASSWORD"
              }
            }
          }
          env {
            name = "REDISCLI_AUTH"
            value_from {
              secret_key_ref {
                name = "enforcer_api_backend_secrets"
                key  = "REDIS_PASSWORD"
              }
            }
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
        }
        volume {
          name = "config"
          secret {
            secret_name = "enforcer_ui_frontend_secrets"
          }
        }
      }
    }
  }
}
