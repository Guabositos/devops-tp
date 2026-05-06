output "app_namespace" {
  description = "Namespace de l'application"
  value       = kubernetes_namespace.app.metadata[0].name
}

output "monitoring_namespace" {
  description = "Namespace du monitoring"
  value       = kubernetes_namespace.monitoring.metadata[0].name
}

output "grafana_nodeport" {
  description = "Port NodePort de Grafana"
  value       = "32000"
}

output "grafana_url" {
  description = "URL Grafana (minikube)"
  value       = "http://$(minikube ip):32000"
}
