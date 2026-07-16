resource "aws_s3_bucket" "loki_logs" {
  bucket        = "${replace(var.project_name, "_", "-")}-loki-logs"
  force_destroy = true
  tags          = local.tags
}

resource "helm_release" "kube_prometheus_stack" {
  name             = "kube-prometheus-stack"
  repository       = "https://prometheus-community.github.io/helm-charts"
  chart            = "kube-prometheus-stack"
  version          = "70.4.2"
  namespace        = "monitoring"
  create_namespace = true

  values = [<<-EOT
    grafana:
      adminPassword: "admin"
      persistence:
        enabled: false
      sidecar:
        dashboards:
          enabled: true
          searchNamespace: ALL
        alerts:
          enabled: true
          searchNamespace: ALL
      additionalDataSources:
        - name: Loki
          type: loki
          uid: loki
          url: http://loki.monitoring.svc.cluster.local:3100
          access: proxy
          isDefault: false
      resources:
        requests:
          cpu: 100m
          memory: 128Mi
        limits:
          cpu: 200m
          memory: 256Mi

    prometheus:
      prometheusSpec:
        retention: 6h
        storageSpec: {}
        serviceMonitorSelectorNilUsesHelmValues: false
        podMonitorSelectorNilUsesHelmValues: false
        resources:
          requests:
            cpu: 200m
            memory: 512Mi
          limits:
            cpu: 500m
            memory: 1Gi

    alertmanager:
      enabled: true
      alertmanagerSpec:
        storage:
          emptyDir: {}
        resources:
          requests:
            cpu: 50m
            memory: 64Mi
          limits:
            cpu: 100m
            memory: 128Mi
      config:
        global:
          resolve_timeout: 5m
        receivers:
          - name: "null"
          - name: solidarytech
            opsgenie_configs:
              - api_key: "${var.opsgenie_api_key}"
                message: "[{{ .Status | toUpper }}] {{ .GroupLabels.alertname }}"
                description: "{{ range .Alerts }}{{ .Annotations.description }}\n{{ end }}"
                tags: "kubernetes,solidarytech,{{ .GroupLabels.namespace }}"
                priority: P1
                send_resolved: true
            slack_configs:
              - api_url: "${var.slack_webhook_url}"
                channel: "#solidarytech-alerts"
                title: "[{{ .Status | toUpper }}] {{ .GroupLabels.alertname }}"
                text: "{{ range .Alerts }}*{{ .Annotations.summary }}*\n{{ .Annotations.description }}\n{{ end }}"
                send_resolved: true
        route:
          group_by: ["alertname", "namespace"]
          group_wait: 30s
          group_interval: 5m
          repeat_interval: 4h
          receiver: "null"
          routes:
            - matchers:
                - name: severity
                  value: critical
              receiver: solidarytech

    kube-state-metrics:
      resources:
        requests:
          cpu: 50m
          memory: 64Mi
        limits:
          cpu: 100m
          memory: 128Mi

    prometheus-node-exporter:
      resources:
        requests:
          cpu: 50m
          memory: 32Mi
        limits:
          cpu: 100m
          memory: 64Mi
  EOT
  ]

  depends_on = [module.eks_mng]
}

resource "helm_release" "loki" {
  name             = "loki"
  repository       = "https://grafana.github.io/helm-charts"
  chart            = "loki"
  version          = "6.7.3"
  namespace        = "monitoring"
  create_namespace = false
  timeout          = 600

  values = [<<-EOT
    deploymentMode: SingleBinary

    loki:
      auth_enabled: false
      commonConfig:
        replication_factor: 1
      storage:
        type: s3
        bucketNames:
          chunks: ${aws_s3_bucket.loki_logs.id}
          ruler: ${aws_s3_bucket.loki_logs.id}
          admin: ${aws_s3_bucket.loki_logs.id}
        s3:
          region: us-east-1
          s3ForcePathStyle: true
      schemaConfig:
        configs:
          - from: "2024-01-01"
            store: tsdb
            object_store: s3
            schema: v13
            index:
              prefix: loki_index_
              period: 24h

    singleBinary:
      replicas: 1
      persistence:
        enabled: false
      extraVolumes:
        - name: loki-tmp
          emptyDir: {}
      extraVolumeMounts:
        - name: loki-tmp
          mountPath: /var/loki
      resources:
        requests:
          cpu: 100m
          memory: 256Mi
        limits:
          cpu: 500m
          memory: 512Mi

    backend:
      replicas: 0
    read:
      replicas: 0
    write:
      replicas: 0
    gateway:
      enabled: false
    chunksCache:
      enabled: false
    resultsCache:
      enabled: false
    lokiCanary:
      enabled: false
    test:
      enabled: false
  EOT
  ]

  depends_on = [helm_release.kube_prometheus_stack]
}

resource "helm_release" "promtail" {
  name             = "promtail"
  repository       = "https://grafana.github.io/helm-charts"
  chart            = "promtail"
  version          = "6.16.6"
  namespace        = "monitoring"
  create_namespace = false

  values = [<<-EOT
    config:
      clients:
        - url: http://loki.monitoring.svc.cluster.local:3100/loki/api/v1/push
  EOT
  ]

  depends_on = [helm_release.loki]
}

resource "kubernetes_secret_v1" "datadog_api_key" {
  metadata {
    name      = "datadog-api-key"
    namespace = "monitoring"
  }

  data = {
    apiKey = var.datadog_api_key
  }

  depends_on = [helm_release.kube_prometheus_stack]
}

resource "kubernetes_secret_v1" "grafana_gitops_pat" {
  metadata {
    name      = "grafana-gitops-pat"
    namespace = "monitoring"
  }

  data = {
    pat = var.gitops_pat
  }

  depends_on = [helm_release.kube_prometheus_stack]
}

resource "helm_release" "otel_collector" {
  name             = "otel-collector"
  repository       = "https://open-telemetry.github.io/opentelemetry-helm-charts"
  chart            = "opentelemetry-collector"
  version          = "0.110.0"
  namespace        = "monitoring"
  create_namespace = false

  values = [<<-EOT
    mode: deployment

    replicaCount: 1

    image:
      repository: otel/opentelemetry-collector-contrib
      tag: "0.110.0"

    extraEnvs:
      - name: DD_API_KEY
        valueFrom:
          secretKeyRef:
            name: datadog-api-key
            key: apiKey

    config:
      receivers:
        otlp:
          protocols:
            grpc:
              endpoint: 0.0.0.0:4317
            http:
              endpoint: 0.0.0.0:4318

      processors:
        memory_limiter:
          check_interval: 1s
          limit_mib: 200
        batch:
          timeout: 5s
          send_batch_size: 512

      exporters:
        datadog:
          api:
            site: us5.datadoghq.com
            key: $${env:DD_API_KEY}

      service:
        pipelines:
          traces:
            receivers: [otlp]
            processors: [memory_limiter, batch]
            exporters: [datadog]
          metrics:
            receivers: [otlp]
            processors: [memory_limiter, batch]
            exporters: [datadog]

    resources:
      requests:
        cpu: 100m
        memory: 256Mi
      limits:
        cpu: 250m
        memory: 512Mi
  EOT
  ]

  depends_on = [kubernetes_secret_v1.datadog_api_key]
}

# Alertas gerais — taxa de erros HTTP 5xx em todos os serviços
resource "kubectl_manifest" "alert_http_5xx" {
  yaml_body = <<-YAML
    apiVersion: monitoring.coreos.com/v1
    kind: PrometheusRule
    metadata:
      name: solidarytech-alerts
      namespace: monitoring
      labels:
        release: kube-prometheus-stack
    spec:
      groups:
        - name: solidarytech.http
          rules:
            - alert: HighHTTP5xxRate
              expr: >
                sum(rate(donation_http_requests_total{path!="/health",status=~"5.."}[5m]))
                /
                sum(rate(donation_http_requests_total{path!="/health"}[5m]))
                > 0.05
              for: 1m
              labels:
                severity: critical
                service: donation-service
              annotations:
                summary: "Alta taxa de erros HTTP 5xx no donation-service"
                description: "donation-service com taxa de erros 5xx acima de 5% (atual: {{ $value | humanizePercentage }})"
  YAML

  depends_on = [helm_release.kube_prometheus_stack]
}

# SLO alerts — donation-service (Hot Path)
# SLO 1: latência p99 < 300ms | SLO 2: error rate < 0.1%
resource "kubectl_manifest" "alert_donation_slo" {
  yaml_body = <<-YAML
    apiVersion: monitoring.coreos.com/v1
    kind: PrometheusRule
    metadata:
      name: donation-service-slo
      namespace: monitoring
      labels:
        release: kube-prometheus-stack
    spec:
      groups:
        - name: donation-service.slo
          rules:
            - alert: DonationServiceHighLatency
              expr: >
                histogram_quantile(0.99,
                  sum(rate(donation_http_request_duration_seconds_bucket{path!="/health"}[5m])) by (le)
                ) > 0.3
              for: 1m
              labels:
                severity: critical
                service: donation-service
                slo: latency
              annotations:
                summary: "SLO violado: latência p99 do donation-service acima de 300ms"
                description: "Latência p99 atual: {{ $value | humanizeDuration }}. SLO: < 300ms (99.9% das requisições)"

            - alert: DonationServiceHighErrorRate
              expr: >
                sum(rate(donation_http_requests_total{path!="/health",status=~"5.."}[5m]))
                /
                sum(rate(donation_http_requests_total{path!="/health"}[5m]))
                > 0.001
              for: 1m
              labels:
                severity: critical
                service: donation-service
                slo: error_rate
              annotations:
                summary: "SLO violado: taxa de erros 5xx do donation-service acima de 0.1%"
                description: "Taxa de erros atual: {{ $value | humanizePercentage }}. SLO: < 0.1% de respostas 5xx"
  YAML

  depends_on = [helm_release.kube_prometheus_stack]
}
