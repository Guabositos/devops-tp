# ── Namespace application ─────────────────────────────────────────────────────
resource "kubernetes_namespace" "app" {
  metadata {
    name = var.app_namespace
    labels = {
      "managed-by" = "terraform"
      "tp"         = "devops"
    }
  }
}

# ── Namespace monitoring ──────────────────────────────────────────────────────
resource "kubernetes_namespace" "monitoring" {
  metadata {
    name = var.monitoring_namespace
    labels = {
      "managed-by" = "terraform"
    }
  }
}

# ── Stack Prometheus + Grafana via Helm ───────────────────────────────────────
resource "helm_release" "kube_prometheus" {
  name       = "kube-prometheus-stack"
  repository = "https://prometheus-community.github.io/helm-charts"
  chart      = "kube-prometheus-stack"
  version    = "60.3.0"
  namespace  = kubernetes_namespace.monitoring.metadata[0].name

  # Grafana : accès NodePort pour le TP
  set {
    name  = "grafana.service.type"
    value = "NodePort"
  }
  set {
    name  = "grafana.service.nodePort"
    value = "32000"
  }
  # Mot de passe admin Grafana (à externaliser en secret en prod)
  set {
    name  = "grafana.adminPassword"
    value = "DevOpsTP2024!"
  }
  # Prometheus : rétention 7 jours
  set {
    name  = "prometheus.prometheusSpec.retention"
    value = "7d"
  }
  # Activer le scraping des namespaces avec l'annotation prometheus.io/scrape
  set {
    name  = "prometheus.prometheusSpec.podMonitorSelectorNilUsesHelmValues"
    value = "false"
  }
  set {
    name  = "prometheus.prometheusSpec.serviceMonitorSelectorNilUsesHelmValues"
    value = "false"
  }

  depends_on = [kubernetes_namespace.monitoring]
}

# ── ServiceMonitor pour scraper l'app Flask ───────────────────────────────────
resource "kubernetes_manifest" "app_service_monitor" {
  manifest = {
    apiVersion = "monitoring.coreos.com/v1"
    kind       = "ServiceMonitor"
    metadata = {
      name      = "flask-app-monitor"
      namespace = var.monitoring_namespace
      labels = {
        release = "kube-prometheus-stack"
      }
    }
    spec = {
      namespaceSelector = {
        matchNames = [var.app_namespace]
      }
      selector = {
        matchLabels = {
          app = "devops-tp-flask"
        }
      }
      endpoints = [{
        port     = "http"
        path     = "/metrics"
        interval = "15s"
      }]
    }
  }
  depends_on = [helm_release.kube_prometheus]
}
