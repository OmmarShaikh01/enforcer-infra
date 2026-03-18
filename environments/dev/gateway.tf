# ======================================================================================================================
# GATEWAY
# ======================================================================================================================
locals {
  http_routes = {
    "prometheus"  = 9090
    "alloy"       = 12345
    "grafana"     = 3000
    "api-backend" = 8000
    "ui-frontend" = 3000
  }
  tls_routes = {
    "postgres" = 5432
    "redis"    = 6379
  }
}


resource "kubernetes_manifest" "enforcer-gateway" {
  manifest = {
    "apiVersion" = "gateway.networking.k8s.io/v1"
    "kind"       = "Gateway"
    "metadata" = {
      "annotations" = {
        "prometheus.io/port"   = "24231"
        "prometheus.io/scrape" = "true"
      }
      "labels" = {
        "name"    = "enforcer-gateway"
        "tier"    = "network"
        "version" = var.enforcer_version
      }
      "name"      = "enforcer-gateway"
      "namespace" = var.deployment_namespace
    }
    "spec" = {
      "gatewayClassName" = "nginx"
      "listeners" = [
        # HTTP
        {
          "name"     = "enforcer-prometheus-listener"
          "port"     = 9000
          "protocol" = "HTTP"
        },
        {
          "name"     = "enforcer-alloy-listener"
          "port"     = 9010
          "protocol" = "HTTP"
        },
        {
          "name"     = "enforcer-grafana-listener"
          "port"     = 9020
          "protocol" = "HTTP"
        },
        {
          "name"     = "enforcer-api-backend-listener"
          "port"     = 9030
          "protocol" = "HTTP"
        },
        {
          "name"     = "enforcer-ui-frontend-listener"
          "port"     = 9040
          "protocol" = "HTTP"
        },
      ]
    }
  }
}

# ======================================================================================================================
# HTTP - ROUTES
# ======================================================================================================================
resource "kubernetes_manifest" "enforcer-srvc-routes" {
  for_each = local.http_routes

  manifest = {
    "apiVersion" = "gateway.networking.k8s.io/v1"
    "kind"       = "HTTPRoute"
    "metadata" = {
      "labels" = {
        "name"    = format("enforcer-%s-srvc-routes", each.key)
        "tier"    = "network"
        "version" = var.enforcer_version
      }
      "name"      = format("enforcer-%s-srvc-routes", each.key)
      "namespace" = var.deployment_namespace
    }
    "spec" = {
      "hostnames" = [
        var.origin_hostname,
      ]
      "parentRefs" = [
        {
          "name"        = "enforcer-gateway"
          "sectionName" = format("enforcer-%s-listener", each.key)
        },
      ]
      "rules" = [
        {
          "backendRefs" = [
            {
              "name" = format("enforcer-%s-srvc", each.key)
              "port" = each.value
            },
          ]
          "matches" = [
            {
              "path" = {
                "type"  = "PathPrefix"
                "value" = "/"
              }
            },
          ]
        },
      ]
    }
  }
}