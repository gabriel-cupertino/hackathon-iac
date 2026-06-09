resource "helm_release" "argocd" {
  name             = "argocd"
  repository       = "https://argoproj.github.io/argo-helm"
  chart            = "argo-cd"
  version          = "5.51.6"
  namespace        = "argocd"
  create_namespace = true

  values = [<<-EOT
    dex:
      enabled: false
    notifications:
      enabled: false
    applicationset:
      enabled: false
  EOT
  ]

  depends_on = [module.eks_mng]
}

resource "kubernetes_secret_v1" "argocd_gitops_repo" {
  metadata {
    name      = "gitops-repo-secret"
    namespace = "argocd"
    labels = {
      "argocd.argoproj.io/secret-type" = "repository"
    }
  }

  data = {
    type     = "git"
    url      = "https://github.com/gabriel-cupertino/hackathon-gitops.git"
    username = "gabriel-cupertino"
    password = var.gitops_pat
  }

  depends_on = [helm_release.argocd]
}

resource "kubectl_manifest" "argocd_app_ngo" {
  yaml_body = <<-YAML
    apiVersion: argoproj.io/v1alpha1
    kind: Application
    metadata:
      name: ngo-service
      namespace: argocd
    spec:
      project: default
      source:
        repoURL: https://github.com/gabriel-cupertino/hackathon-gitops.git
        targetRevision: HEAD
        path: ngo-service
      destination:
        server: https://kubernetes.default.svc
        namespace: ngo-service
      syncPolicy:
        automated:
          prune: true
          selfHeal: true
        syncOptions:
          - CreateNamespace=true
  YAML

  depends_on = [helm_release.argocd, kubernetes_secret_v1.argocd_gitops_repo]
}

resource "kubectl_manifest" "argocd_app_donation" {
  yaml_body = <<-YAML
    apiVersion: argoproj.io/v1alpha1
    kind: Application
    metadata:
      name: donation-service
      namespace: argocd
    spec:
      project: default
      source:
        repoURL: https://github.com/gabriel-cupertino/hackathon-gitops.git
        targetRevision: HEAD
        path: donation-service
      destination:
        server: https://kubernetes.default.svc
        namespace: donation-service
      syncPolicy:
        automated:
          prune: true
          selfHeal: true
        syncOptions:
          - CreateNamespace=true
  YAML

  depends_on = [helm_release.argocd, kubernetes_secret_v1.argocd_gitops_repo]
}

resource "kubectl_manifest" "argocd_app_volunteer" {
  yaml_body = <<-YAML
    apiVersion: argoproj.io/v1alpha1
    kind: Application
    metadata:
      name: volunteer-service
      namespace: argocd
    spec:
      project: default
      source:
        repoURL: https://github.com/gabriel-cupertino/hackathon-gitops.git
        targetRevision: HEAD
        path: volunteer-service
      destination:
        server: https://kubernetes.default.svc
        namespace: volunteer-service
      syncPolicy:
        automated:
          prune: true
          selfHeal: true
        syncOptions:
          - CreateNamespace=true
  YAML

  depends_on = [helm_release.argocd, kubernetes_secret_v1.argocd_gitops_repo]
}
