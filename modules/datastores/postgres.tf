# ======================================================================================================================
# RBAC
# ======================================================================================================================
resource "kubernetes_service_account_v1" "enforcer-postgres-sa" {
  metadata {
    name      = "postgres"
    namespace = local.deployment_namespace
    labels = {
      name    = "enforcer-postgres-sa"
      tier    = local.tier
      version = local.version
    }
  }
}

resource "kubernetes_cluster_role_v1" "enforcer-postgres-cr" {
  metadata {
    name = "enforcer-postgres-cr"
    labels = {
      name    = "enforcer-postgres-cr"
      tier    = local.tier
      version = local.version
    }
  }
}

resource "kubernetes_cluster_role_binding_v1" "enforcer-postgres-binds" {
  metadata {
    name = "enforcer-postgres-binds"
    labels = {
      name    = "enforcer-postgres-binds"
      tier    = local.tier
      version = local.version
    }
  }
  role_ref {
    api_group = "rbac.authorization.k8s.io"
    kind      = "ClusterRole"
    name      = kubernetes_cluster_role_v1.enforcer-postgres-cr.metadata[0].name
  }
  subject {
    namespace = local.deployment_namespace
    kind      = "ServiceAccount"
    name      = kubernetes_service_account_v1.enforcer-postgres-sa.metadata[0].name
  }
}

# ======================================================================================================================
# NETWORK
# ======================================================================================================================
resource "kubernetes_service_v1" "enforcer-postgres-srvc" {
  metadata {
    name      = "enforcer-postgres-srvc"
    namespace = local.deployment_namespace
    labels = {
      name    = "enforcer-postgres-srvc"
      tier    = local.tier
      version = local.version
    }
  }
  spec {
    selector = {
      name = "enforcer-postgres"
    }
    port {
      name         = "database"
      port         = "5432"
      target_port  = "6432"
      app_protocol = "TCP"
    }
  }
}

# ======================================================================================================================
# STORAGE
# ======================================================================================================================
resource "kubernetes_persistent_volume_claim_v1" "enforcer-postgres-pvc" {
  metadata {
    name      = "enforcer-postgres-pvc"
    namespace = local.deployment_namespace
    labels = {
      name    = "enforcer-postgres-pvc"
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

resource "kubernetes_config_map_v1" "enforcer-postgres-config" {
  metadata {
    name      = "enforcer-postgres-config"
    namespace = local.deployment_namespace
    labels = {
      name    = "enforcer-postgres-config"
      tier    = local.tier
      version = local.version
    }
  }
  data = {
    "postgres.conf" = local.config_templates.config_postgres.postgres_conf
    "pg_hba.conf"   = local.config_templates.config_postgres.hba_conf
  }
}

resource "kubernetes_secret_v1" "enforcer-postgres-secrets" {
  metadata {
    name      = "enforcer-postgres-secrets"
    namespace = local.deployment_namespace
    labels = {
      name    = "enforcer-postgres-secrets"
      tier    = local.tier
      version = local.version
    }
  }
  immutable = true
  data = {
    POSTGRES_USER     = var.enforcer_secrets.postgres.username
    POSTGRES_PASSWORD = var.enforcer_secrets.postgres.password
    POSTGRES_DB       = var.enforcer_secrets.postgres.name
  }
}

# ======================================================================================================================
# DEPLOYMENT
# ======================================================================================================================
resource "kubernetes_stateful_set_v1" "enforcer-postgres" {
  metadata {
    name      = kubernetes_service_v1.enforcer-postgres-srvc.spec[0].selector.name
    namespace = local.deployment_namespace
    labels = {
      name        = kubernetes_service_v1.enforcer-postgres-srvc.spec[0].selector.name
      tier        = local.tier
      version     = local.version
      config_hash = md5("${local.config_templates.config_postgres.postgres_conf}${local.config_templates.config_postgres.hba_conf}")
    }
  }
  spec {
    service_name = kubernetes_service_v1.enforcer-postgres-srvc.spec[0].selector.name
    selector {
      match_labels = {
        name = kubernetes_service_v1.enforcer-postgres-srvc.spec[0].selector.name
      }
    }
    template {
      metadata {
        labels = {
          name    = kubernetes_service_v1.enforcer-postgres-srvc.spec[0].selector.name
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
        service_account_name             = kubernetes_service_account_v1.enforcer-postgres-sa.metadata[0].name
        security_context {
          run_as_non_root = true
        }
        container {
          name  = "enforcer-db-lb"
          image = var.images.image_postgres_lb
          security_context {
            allow_privilege_escalation = false
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
          port {
            name           = kubernetes_service_v1.enforcer-postgres-srvc.spec[0].port[0].name
            container_port = kubernetes_service_v1.enforcer-postgres-srvc.spec[0].port[0].target_port
            protocol       = kubernetes_service_v1.enforcer-postgres-srvc.spec[0].port[0].app_protocol
          }
          env {
            name  = "DB_HOST"
            value = "127.0.0.1"
          }
          env {
            name  = "AUTH_QUERY"
            value = "SELECT usename, passwd FROM pg_shadow WHERE usename=$1"
          }
          env {
            name  = "LISTEN_PORT"
            value = "6432"
          }
          env {
            name  = "POOL_MODE"
            value = "transaction"
          }
          env {
            name  = "MAX_CLIENT_CONN"
            value = "1000"
          }
          env {
            name  = "AUTH_TYPE"
            value = "scram-sha-256"
          }
          env {
            name = "DB_NAME"
            value_from {
              secret_key_ref {
                name = kubernetes_secret_v1.enforcer-postgres-secrets.metadata[0].name
                key  = "POSTGRES_DB"
              }
            }
          }
          env {
            name = "DB_USER"
            value_from {
              secret_key_ref {
                name = kubernetes_secret_v1.enforcer-postgres-secrets.metadata[0].name
                key  = "POSTGRES_USER"
              }
            }
          }
          env {
            name = "DB_PASSWORD"
            value_from {
              secret_key_ref {
                name = kubernetes_secret_v1.enforcer-postgres-secrets.metadata[0].name
                key  = "POSTGRES_PASSWORD"
              }
            }
          }
          env {
            name = "AUTH_USER"
            value_from {
              secret_key_ref {
                name = kubernetes_secret_v1.enforcer-postgres-secrets.metadata[0].name
                key  = "POSTGRES_PASSWORD"
              }
            }
          }
        }
        container {
          name  = "enforcer-db"
          image = var.images.image_postgres
          args = [
            "-c",
            "config_file=/etc/postgresql/postgres.conf",
            "-c",
            "hba_file=/etc/postgresql/pg_hba.conf",
            "-p",
            "5432",
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
            name           = kubernetes_service_v1.enforcer-postgres-srvc.spec[0].port[0].name
            container_port = kubernetes_service_v1.enforcer-postgres-srvc.spec[0].port[0].port
            protocol       = kubernetes_service_v1.enforcer-postgres-srvc.spec[0].port[0].app_protocol
          }
          env {
            name = "POSTGRES_DB"
            value_from {
              secret_key_ref {
                name = kubernetes_secret_v1.enforcer-postgres-secrets.metadata[0].name
                key  = "POSTGRES_DB"
              }
            }
          }
          env {
            name = "POSTGRES_USER"
            value_from {
              secret_key_ref {
                name = kubernetes_secret_v1.enforcer-postgres-secrets.metadata[0].name
                key  = "POSTGRES_USER"
              }
            }
          }
          env {
            name = "POSTGRES_PASSWORD"
            value_from {
              secret_key_ref {
                name = kubernetes_secret_v1.enforcer-postgres-secrets.metadata[0].name
                key  = "POSTGRES_PASSWORD"
              }
            }
          }
          readiness_probe {
            exec {
              command = [
                "/bin/sh",
                "-c",
                "psql -w -U $POSTGRES_USER -d $POSTGRES_DB -c SELECT 1"
              ]
            }
            initial_delay_seconds = 60
            failure_threshold = 4
          }
          liveness_probe {
            exec {
              command = [
                "/bin/sh",
                "-c",
                "psql -w -U $POSTGRES_USER -d $POSTGRES_DB -c SELECT 1"
              ]
            }
            initial_delay_seconds = 90
            failure_threshold = 4
          }

          volume_mount {
            name       = "storage"
            mount_path = "/var/lib/postgresql"
          }
          volume_mount {
            name       = "config"
            mount_path = "/etc/postgresql"
          }
        }
        volume {
          name = "config"
          config_map {
            name = kubernetes_config_map_v1.enforcer-postgres-config.metadata[0].name
          }
        }
        volume {
          name = "storage"
          persistent_volume_claim {
            claim_name = "enforcer-postgres-pvc"
          }
        }
      }
    }
  }
}