# ======================================================================================================================
# REQUIRED
# ======================================================================================================================
variable "kube_context" {
  type        = string
  description = "Path to the Kubernetes config file"
}

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

variable "environment" {
  type        = string
  description = "Environment"
}

# ======================================================================================================================
# OPTIONALS
# ======================================================================================================================
variable "repository_url" {
  type        = string
  description = "Path to the Repository URL"
  default     = "localhost:5000"
}

variable "kube_config_path" {
  type        = string
  default     = "~/.kube/config"
  description = "Path to the Kubernetes config file"
}

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

variable "origin_hostname" {
  type        = string
  description = "Hostname to accept connections from"
  default     = "localhost"
}