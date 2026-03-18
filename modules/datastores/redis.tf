# ======================================================================================================================
# RBAC
# ======================================================================================================================
resource "kubernetes_service_account_v1" "enforcer-redis-sa" {
  metadata {
    name      = "redis"
    namespace = local.deployment_namespace
    labels = {
      name    = "enforcer-redis-sa"
      tier    = local.tier
      version = local.version
    }
  }
}

resource "kubernetes_cluster_role_v1" "enforcer-redis-cr" {
  metadata {
    name = "enforcer-redis-cr"
    labels = {
      name    = "enforcer-redis-cr"
      tier    = local.tier
      version = local.version
    }
  }
}

resource "kubernetes_cluster_role_binding_v1" "enforcer-redis-binds" {
  metadata {
    name = "enforcer-redis-binds"
    labels = {
      name    = "enforcer-redis-binds"
      tier    = local.tier
      version = local.version
    }
  }
  role_ref {
    api_group = "rbac.authorization.k8s.io"
    kind      = "ClusterRole"
    name      = kubernetes_cluster_role_v1.enforcer-redis-cr.metadata[0].name
  }
  subject {
    namespace = local.deployment_namespace
    kind      = "ServiceAccount"
    name      = kubernetes_service_account_v1.enforcer-redis-sa.metadata[0].name
  }
}

# ======================================================================================================================
# NETWORK
# ======================================================================================================================
resource "kubernetes_service_v1" "enforcer-redis-srvc" {
  metadata {
    name      = "enforcer-redis-srvc"
    namespace = local.deployment_namespace
    labels = {
      name    = "enforcer-redis-srvc"
      tier    = local.tier
      version = local.version
    }
  }
  spec {
    selector = {
      name = "enforcer-redis"
    }
    port {
      name         = "database"
      port         = "6379"
      target_port  = "6379"
      app_protocol = "TCP"
    }
  }
}

# ======================================================================================================================
# STORAGE
# ======================================================================================================================
resource "kubernetes_persistent_volume_claim_v1" "enforcer-redis-pvc" {
  metadata {
    name      = "enforcer-redis-pvc"
    namespace = local.deployment_namespace
    labels = {
      name    = "enforcer-redis-pvc"
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

resource "kubernetes_secret_v1" "enforcer-redis-secrets" {
  metadata {
    name      = "enforcer-redis-secrets"
    namespace = local.deployment_namespace
    labels = {
      name    = "enforcer-redis-secrets"
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

resource "kubernetes_secret_v1" "enforcer-redis-acl" {
  metadata {
    name      = "enforcer-redis-acl"
    namespace = local.deployment_namespace
    labels = {
      name    = "enforcer-redis-acl"
      tier    = local.tier
      version = local.version
    }
  }
  immutable = true
  data = {
    "users.acl" = <<-EOF
    user ${var.enforcer_secrets.redis.username} on >${var.enforcer_secrets.redis.username} ~* &* +@all
    user default off
    EOF
  }
}

resource "kubernetes_secret_v1" "enforcer-redis-seed-script" {
  metadata {
    name      = "enforcer-redis-seed-script"
    namespace = local.deployment_namespace
    labels = {
      name    = "enforcer-redis-seed-script"
      tier    = local.tier
      version = local.version
    }
  }
  immutable = true
  data = {
    "seed.sh" = templatefile(
      local.config_templates.config_redis.seed,
      {
        __REDIS_USER__ : var.enforcer_secrets.redis.username,
        __REDIS_PASS__ : var.enforcer_secrets.redis.password,
        __POSTGRES_USER__ : var.enforcer_secrets.postgres.username,
        __POSTGRES_PASS__ : var.enforcer_secrets.postgres.password,
        __POSTGRES_DB__ : var.enforcer_secrets.postgres.name,
      }
    )
  }
}

# ======================================================================================================================
# DEPLOYMENT
# ======================================================================================================================
resource "kubernetes_stateful_set_v1" "enforcer-redis" {
  metadata {
    name      = kubernetes_service_v1.enforcer-redis-srvc.spec[0].selector.name
    namespace = local.deployment_namespace
    labels = {
      name    = kubernetes_service_v1.enforcer-redis-srvc.spec[0].selector.name
      tier    = local.tier
      version = local.version
    }
  }
  spec {
    service_name = kubernetes_service_v1.enforcer-redis-srvc.spec[0].selector.name
    selector {
      match_labels = {
        name = kubernetes_service_v1.enforcer-redis-srvc.spec[0].selector.name
      }
    }
    template {
      metadata {
        labels = {
          name    = kubernetes_service_v1.enforcer-redis-srvc.spec[0].selector.name
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
        service_account_name             = kubernetes_service_account_v1.enforcer-redis-sa.metadata[0].name
        security_context {
          fs_group        = "999"
          run_as_user     = "999"
          run_as_non_root = true
        }
        container {
          name  = kubernetes_service_v1.enforcer-redis-srvc.spec[0].selector.name
          image = var.images.image_redis
          command = [
            "redis-server",
            "--appendonly",
            "yes",
            "--aclfile",
            "/etc/redis/users.acl"
          ]
          security_context {
            allow_privilege_escalation = false
          }
          resources {
            limits = {
              cpu    = "2"
              memory = "2Gi"
            }
            requests = {
              cpu    = "100m"
              memory = "200Mi"
            }
          }
          port {
            name           = kubernetes_service_v1.enforcer-redis-srvc.spec[0].port[0].name
            container_port = kubernetes_service_v1.enforcer-redis-srvc.spec[0].port[0].target_port
            protocol       = kubernetes_service_v1.enforcer-redis-srvc.spec[0].port[0].app_protocol
          }
          env {
            name = "REDISCLI_AUTH"
            value_from {
              secret_key_ref {
                name = kubernetes_secret_v1.enforcer-redis-secrets.metadata[0].name
                key  = "REDIS_PASSWORD"
              }
            }
          }
          env {
            name = "REDIS_USERNAME"
            value_from {
              secret_key_ref {
                name = kubernetes_secret_v1.enforcer-redis-secrets.metadata[0].name
                key  = "REDIS_USER"
              }
            }
          }
          env {
            name = "REDIS_PASSWORD"
            value_from {
              secret_key_ref {
                name = kubernetes_secret_v1.enforcer-redis-secrets.metadata[0].name
                key  = "REDIS_PASSWORD"
              }
            }
          }
          readiness_probe {
            exec {
              command = ["redis-cli", "-h", "localhost", "--user", "$REDIS_USERNAME", "info", "|", "grep", "loading", "|", "grep", "0"]
            }
            initial_delay_seconds = 60
            failure_threshold     = 4
          }
          liveness_probe {
            exec {
              command = ["redis-cli", "-h", "localhost", "--user", "$REDIS_USERNAME", "info", "|", "grep", "loading", "|", "grep", "0"]
            }
            initial_delay_seconds = 60
            failure_threshold     = 4
          }
          volume_mount {
            name       = "storage"
            mount_path = "/data"
          }
          volume_mount {
            name       = "vault-acl"
            mount_path = "/etc/redis/users.acl"
            sub_path   = "users.acl"
            read_only  = true
          }
        }

        volume {
          name = "vault-acl"
          secret {
            secret_name = kubernetes_secret_v1.enforcer-redis-acl.metadata[0].name
          }
        }
        volume {
          name = "storage"
          persistent_volume_claim {
            claim_name = "enforcer-redis-pvc"
          }
        }
      }
    }
  }
}

# ======================================================================================================================
# BATCH JOBS
# ======================================================================================================================
resource "kubernetes_job_v1" "enforcer-redis-seed-job" {
  depends_on = [
    kubernetes_stateful_set_v1.enforcer-redis
  ]

  metadata {
    name      = "enforcer-redis-seed-job"
    namespace = local.deployment_namespace
    labels = {
      name    = "enforcer-redis-seed-job"
      tier    = local.tier
      version = local.version
    }

    annotations = {
      "prometheus.io/port"   = "24231"
      "prometheus.io/scrape" = "true"
    }

  }
  spec {
    backoff_limit              = 3
    ttl_seconds_after_finished = "300"
    template {
      metadata {
        labels = {
          name    = "enforcer-redis-seed-job"
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
        service_account_name             = kubernetes_service_account_v1.enforcer-redis-sa.metadata[0].name
        security_context {
          fs_group        = "999"
          run_as_user     = "999"
          run_as_non_root = true
        }
        container {
          name  = "enforcer-redis-seed-job"
          image = var.images.image_redis
          command = [
            "/seed.sh"
          ]
          security_context {
            allow_privilege_escalation = false
          }
          resources {
            requests = {
              cpu    = "100m"
              memory = "200Mi"
            }
            limits = {
              cpu    = "200m"
              memory = "500Mi"
            }
          }
          env {
            name  = "REDIS_HOST"
            value = kubernetes_service_v1.enforcer-redis-srvc.metadata[0].name
          }
          env {
            name = "REDISCLI_AUTH"
            value_from {
              secret_key_ref {
                name = kubernetes_secret_v1.enforcer-redis-secrets.metadata[0].name
                key  = "REDIS_PASSWORD"
              }
            }
          }
          env {
            name = "REDIS_USERNAME"
            value_from {
              secret_key_ref {
                name = kubernetes_secret_v1.enforcer-redis-secrets.metadata[0].name
                key  = "REDIS_USER"
              }
            }
          }
          env {
            name = "REDIS_PASSWORD"
            value_from {
              secret_key_ref {
                name = kubernetes_secret_v1.enforcer-redis-secrets.metadata[0].name
                key  = "REDIS_PASSWORD"
              }
            }
          }
          volume_mount {
            name       = "seed-script"
            mount_path = "/seed.sh"
            sub_path   = "seed.sh"
            read_only  = true
          }
        }
        volume {
          name = "seed-script"
          secret {
            secret_name  = kubernetes_secret_v1.enforcer-redis-seed-script.metadata[0].name
            default_mode = "0777"
          }
        }
      }
    }
  }
}