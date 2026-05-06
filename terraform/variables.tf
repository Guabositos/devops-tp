variable "kubeconfig_path" {
  description = "Chemin vers le fichier kubeconfig"
  type        = string
  default     = "~/.kube/config"
}

variable "kube_context" {
  description = "Contexte Kubernetes à utiliser (ex: minikube, kind-kind)"
  type        = string
  default     = "minikube"
}

variable "app_namespace" {
  description = "Namespace Kubernetes pour l'application"
  type        = string
  default     = "devops-tp"
}

variable "monitoring_namespace" {
  description = "Namespace pour la stack Prometheus/Grafana"
  type        = string
  default     = "monitoring"
}

variable "docker_image" {
  description = "Image Docker de l'application (injectée par Jenkins)"
  type        = string
  default     = "monuser/devops-tp-flask:latest"
}

variable "app_replicas" {
  description = "Nombre de réplicas de l'application"
  type        = number
  default     = 2
}
