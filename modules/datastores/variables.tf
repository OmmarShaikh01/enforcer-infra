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
    image_postgres    = string
    image_postgres_lb = string
    image_redis       = string
  })
}

variable "environemnt" {
  type        = string
  description = "Environemnt"
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
