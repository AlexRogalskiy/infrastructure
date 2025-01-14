resource "kubernetes_namespace" "main" {
  metadata {
    name = "wavefront-proxy"
  }
}

resource "kubernetes_secret" "main" {
  metadata {
    name      = "wavefront"
    namespace = kubernetes_namespace.main.metadata.0.name
  }

  type = "Opaque"

  data = {
    token = var.token
  }
}

resource "kubernetes_deployment" "main" {
  metadata {
    name      = "wavefront-proxy"
    namespace = kubernetes_namespace.main.metadata.0.name
    labels = {
      app = "wavefront-proxy"
    }
  }

  spec {
    replicas = 1
    selector {
      match_labels = {
        app = "wavefront-proxy"
      }
    }

    template {
      metadata {
        labels = {
          app = "wavefront-proxy"
        }
      }

      spec {
        container {
          name  = "prom-storage-adapter"
          image = "wavefronthq/prometheus-storage-adapter"

          args = [
            "-proxy=127.0.0.1",
            "-proxy-port=2878",
            "-listen=9000",
            "-convert-paths=true"
          ]

          port {
            container_port = 9000
          }

          resources {
            limits = {
              cpu    = "0.5"
              memory = "1Gi"
            }
            requests = {
              cpu    = "0.5"
              memory = "512Mi"
            }
          }

        }
        container {
          name  = "wavefront-proxy"
          image = "wavefronthq/proxy:9.2"

          port {
            container_port = 14250
          }

          env {
            name  = "WAVEFRONT_URL"
            value = "https://vmware.wavefront.com/api/"
          }
          env {
            name  = "WAVEFRONT_PROXY_ARGS"
            value = <<-EOT
            --prefix ${var.prefix}
            --hostname ${var.url}
            --traceJaegerGrpcListenerPorts 14250
            --traceJaegerApplicationName ${var.prefix}
            EOT
          }
          env {
            name = "WAVEFRONT_TOKEN"
            value_from {
              secret_key_ref {
                name = kubernetes_secret.main.metadata.0.name
                key  = "token"
              }
            }
          }

          resources {
            limits = {
              cpu    = "1"
              memory = "2Gi"
            }
            requests = {
              cpu    = "1"
              memory = "1Gi"
            }
          }

        }
      }
    }
  }
}

resource "kubernetes_service" "tracing" {
  metadata {
    name      = "tracing"
    namespace = kubernetes_namespace.main.metadata.0.name
  }
  spec {
    selector = {
      app = "wavefront-proxy"
    }

    port {
      port        = 14250
      target_port = 14250
    }
    type = "ClusterIP"
  }
}

resource "kubernetes_service" "metrics" {
  metadata {
    name      = "metrics"
    namespace = kubernetes_namespace.main.metadata.0.name
  }
  spec {
    selector = {
      app = "wavefront-proxy"
    }

    port {
      port        = 9000
      target_port = 9000
    }
    type = "ClusterIP"
  }
}
