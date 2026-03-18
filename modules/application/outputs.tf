output "endpoints" {
  value = {
    api_backend = {
      service_endpoint = kubernetes_service_v1.enforcer_api_backend_srvc.metadata[0].name
      listener = {
        container_port = kubernetes_service_v1.enforcer_api_backend_srvc.spec[0].port[0].port
        protocol       = kubernetes_service_v1.enforcer_api_backend_srvc.spec[0].port[0].app_protocol
      }
    }
    ui_frontend = {
      service_endpoint = kubernetes_service_v1.enforcer_ui_frontend_srvc.metadata[0].name
      listener = {
        container_port = kubernetes_service_v1.enforcer_ui_frontend_srvc.spec[0].port[0].port
        protocol       = kubernetes_service_v1.enforcer_ui_frontend_srvc.spec[0].port[0].app_protocol
      }
    }
  }
}
