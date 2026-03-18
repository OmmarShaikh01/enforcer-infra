# ======================================================================================================================
# REQUIRED
# ======================================================================================================================
variable "enforcer_secrets" {
  type = object({
    grafana = object({
      username = string
      password = string
    })
    postgres = object({
      username = string
      password = string
      name     = string
    })
    redis = object({
      username = string
      password = string
      name     = string
    })
  })
  sensitive = true
}

variable "images" {
  type = object({
    image_alloy      = string
    image_loki       = string
    image_grafana    = string
    image_prometheus = string
  })
}

variable "environment" {
  type        = string
  description = "Environment"
}

# ======================================================================================================================
# OPTIONALS
# ======================================================================================================================
variable "deployment_namespace" {
  type        = string
  default     = "enforcer"
  description = "Kubernetes namespace for the deployment"
}

variable "enforcer_version" {
  type        = string
  description = "Version of the Enforcer application to deploy"
  default     = "0.1.0"
}