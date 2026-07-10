resource "helm_release" "ingress_nginx" {
  name             = "ingress-nginx"
  repository       = "https://kubernetes.github.io/ingress-nginx"
  chart            = "ingress-nginx"
  version          = "4.10.1"
  namespace        = "ingress-nginx"
  create_namespace = true

  set = [
    {
      name  = "controller.service.type"
      value = "LoadBalancer"
    },
    {
      name  = "controller.service.annotations.service\\.beta\\.kubernetes\\.io/aws-load-balancer-type"
      value = "nlb"
    }
  ]

  values = [<<-EOT
    controller:
      metrics:
        enabled: true
        serviceMonitor:
          enabled: true
          namespace: monitoring
          additionalLabels:
            release: kube-prometheus-stack
  EOT
  ]

  depends_on = [module.eks_mng, helm_release.kube_prometheus_stack]
}
