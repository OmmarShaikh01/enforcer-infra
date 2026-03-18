# ======================================================================================================================
# RBAC
# ======================================================================================================================
resource "kubernetes_service_account_v1" "enforcer_api_backend_sa" {
  metadata {
    name      = "api_backend"
    namespace = local.deployment_namespace
    labels = {
      name    = "enforcer_api_backend_sa"
      tier    = local.tier
      version = local.version
    }
  }
}

resource "kubernetes_cluster_role_v1" "enforcer_api_backend_cr" {
  metadata {
    name = "enforcer_api_backend_cr"
    labels = {
      name    = "enforcer_api_backend_cr"
      tier    = local.tier
      version = local.version
    }
  }
}

resource "kubernetes_cluster_role_binding_v1" "enforcer_api_backend_binds" {
  metadata {
    name = "enforcer_api_backend_binds"
    labels = {
      name    = "enforcer_api_backend_binds"
      tier    = local.tier
      version = local.version
    }
  }
  role_ref {
    api_group = "rbac.authorization.k8s.io"
    kind      = "ClusterRole"
    name      = "enforcer_api_backend_cr"
  }
  subject {
    kind      = "ServiceAccount"
    name      = "api_backend"
    namespace = local.deployment_namespace
  }
}

# ======================================================================================================================
# NETWORK
# ======================================================================================================================
resource "kubernetes_service_v1" "enforcer_api_backend_srvc" {
  metadata {
    name      = "enforcer_api_backend_srvc"
    namespace = local.deployment_namespace
    labels = {
      name    = "enforcer_api_backend_srvc"
      tier    = local.tier
      version = local.version
    }
  }
  spec {
    selector = {
      name = "enforcer_api_backend"
    }
    port {
      name         = "listner"
      port         = "8000"
      target_port  = "8000"
      app_protocol = "TCP"
    }
  }
}

# ======================================================================================================================
# STORAGE
# ======================================================================================================================
resource "kubernetes_secret_v1" "enforcer_api_backend_secrets" {
  metadata {
    name      = "enforcer_api_backend_secrets"
    namespace = local.deployment_namespace
    labels = {
      name    = "enforcer_api_backend_secrets"
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
resource "kubernetes_deployment_v1" "enforcer_api_backend" {
  metadata {
    name      = kubernetes_service_v1.enforcer_api_backend_srvc.spec[0].selector.name
    namespace = local.deployment_namespace
    labels = {
      name    = kubernetes_service_v1.enforcer_api_backend_srvc.spec[0].selector.name
      tier    = local.tier
      version = local.version
    }
  }
  spec {
    selector {
      match_labels = {
        name = kubernetes_service_v1.enforcer_api_backend_srvc.spec[0].selector.name
      }
    }
    template {
      metadata {
        labels = {
          name = kubernetes_service_v1.enforcer_api_backend_srvc.spec[0].selector.name
        }
      }
      spec {
        termination_grace_period_seconds = 30
        service_account_name             = kubernetes_service_account_v1.enforcer_api_backend_sa.metadata[0].name
        security_context {
          run_as_non_root = true
          run_as_user     = "120"
          run_as_group    = "120"
        }
        container {
          name              = kubernetes_service_v1.enforcer_api_backend_srvc.spec[0].selector.name
          image             = var.images.image_api_backend
          image_pull_policy = "Always"
          command           = ["/entrypoint.sh"]
          port {
            name           = kubernetes_service_v1.enforcer_api_backend_srvc.spec[0].port[0].name
            container_port = kubernetes_service_v1.enforcer_api_backend_srvc.spec[0].port[0].target_port
            protocol       = kubernetes_service_v1.enforcer_api_backend_srvc.spec[0].port[0].app_protocol
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
            secret_name = "enforcer_api_backend_secrets"
          }
        }
      }
    }
  }
}