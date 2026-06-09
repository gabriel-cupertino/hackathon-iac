resource "kubernetes_namespace_v1" "ngo-service" {
  metadata {
    name = "ngo-service"
  }
}

resource "kubernetes_namespace_v1" "donation-service" {
  metadata {
    name = "donation-service"
  }
}

resource "kubernetes_namespace_v1" "volunteer-service" {
  metadata {
    name = "volunteer-service"
  }
}
