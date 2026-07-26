# hackathon-iac — Infraestrutura como Código (Terraform)

Repositório de **IaC da plataforma SolidaryTech** (Hackathon Fase 5). Provisiona **todo** o ambiente na AWS via Terraform — cluster, bancos, mensageria, rede, GitOps, observabilidade e Disaster Recovery — com tags de FinOps obrigatórias em todos os recursos.

> Regra de ouro: nenhuma infraestrutura é criada no console. Tudo é versionado e reproduzível aqui.

## O que este repo provisiona

| Área | Recursos |
|---|---|
| **Compute** | EKS Cluster + Managed Node Group (t3.medium) |
| **Dados** | RDS PostgreSQL (`ngo-db`, `donation-db`), DynamoDB (volunteers) |
| **Mensageria** | SQS (fila de doações) |
| **Rede** | VPC, subnets públicas/privadas, IGW, NAT Gateway, route tables |
| **Registry** | ECR (3 repositórios, scan on push) |
| **GitOps** | ArgoCD (Helm) + 3 Applications apontando para `hackathon-gitops` |
| **Observabilidade** | kube-prometheus-stack, Loki (S3), Promtail, OTel Collector (→Datadog), AlertManager (→OpsGenie + Slack), PrometheusRules de SLO |
| **DR** | Warm Standby cross-region (us-west-2), ativável por variável |

## Estrutura

```
hackathon-iac/
├── modules/
│   ├── cluster/            # EKS cluster + security group rules
│   ├── manage-node-group/  # Managed node group + launch template (IMDS hop=2)
│   ├── network/            # VPC, subnets, IGW, NAT, route tables
│   ├── resources/          # ECR, RDS, DynamoDB, SQS
│   └── kubernetes/         # namespaces + secrets K8s
├── argocd.tf               # ArgoCD via Helm + 3 Applications
├── ingress-controller.tf   # ingress-nginx (NLB)
├── metrics-server.tf       # base para HPA
├── monitoring.tf           # Prometheus/Grafana/Loki/OTel/AlertManager + regras SLO
├── dr.tf                   # Disaster Recovery (Warm Standby us-west-2)
├── locals.tf               # tags FinOps (Group/Project/Environment/CostCenter)
├── modules.tf              # wiring dos módulos
├── provider.tf             # aws, kubernetes, helm, kubectl + backend S3
├── variables.tf
└── output.tf
```

## Tags FinOps

Definidas em [`locals.tf`](locals.tf) e propagadas via `merge()` a todos os recursos:
`Project=SolidaryTech`, `Environment=Production`, `CostCenter=NGO-Core` (+ `Group`, `Organization`).

## Pré-requisitos

- Terraform + AWS CLI autenticado (no AWS Academy, credenciais rotacionam a cada sessão)
- Backend de state no S3 (`solidarytech-tfstate-fiap`)
- `terraform.tfvars` com os segredos: `opsgenie_api_key`, `slack_webhook_url`, `datadog_api_key`, `gitops_pat`

## Uso

```bash
terraform init
terraform plan
terraform apply
```

> **Quirk conhecido do provider Kubernetes:** os providers `kubernetes`/`kubectl`/`helm` leem o endpoint do EKS via `data.aws_eks_cluster`. Quando o cluster está sendo **alterado** no mesmo apply (ex: mudança de tag), esse data source é adiado e o provider cai para `localhost`. Se isso ocorrer, estabilize o cluster primeiro:
> ```bash
> terraform apply -target=module.eks_cluster -target=module.eks_mng
> terraform apply
> ```

## Disaster Recovery

O DR não sobe por padrão. Para ativar o ambiente espelho (Warm Standby) em us-west-2:

```bash
terraform apply -var="dr_enabled=true" -var="dr_region=us-west-2"
```

Provisiona VPC + EKS + node group + **RDS read replica cross-region** + **ECR replication** na região secundária. **RTO 15 min / RPO 1 h.** Ver detalhes no PCN do projeto.

## Fluxo completo

`Terraform (este repo)` → provisiona EKS + infra → `ArgoCD` sincroniza os manifestos de [`hackathon-gitops`](https://github.com/gabriel-cupertino/hackathon-gitops) → aplicações no ar, monitoradas pela stack de observabilidade.
