# Disaster Recovery — Opção B: Warm Standby via Terraform
#
# Para ativar o ambiente DR na região secundária:
#   terraform apply -var="dr_enabled=true" -var="dr_region=us-west-2"
#
# RTO estimado: 15 minutos (provisionamento da infra + sync do ArgoCD)
# RPO estimado: 1 hora (backup automático do RDS da região primária)

# --- Rede DR ---

resource "aws_vpc" "dr_vpc" {
  count      = var.dr_enabled ? 1 : 0
  provider   = aws.dr
  cidr_block = "10.2.0.0/16"

  enable_dns_support   = true
  enable_dns_hostnames = true

  tags = merge(
    local.tags,
    { Name = "${var.project_name}-dr-vpc" }
  )
}

resource "aws_internet_gateway" "dr_igw" {
  count    = var.dr_enabled ? 1 : 0
  provider = aws.dr
  vpc_id   = aws_vpc.dr_vpc[0].id

  tags = merge(local.tags, { Name = "${var.project_name}-dr-igw" })
}

data "aws_availability_zones" "dr_azs" {
  count    = var.dr_enabled ? 1 : 0
  provider = aws.dr
  state    = "available"
}

resource "aws_subnet" "dr_pub_subnet_1a" {
  count             = var.dr_enabled ? 1 : 0
  provider          = aws.dr
  vpc_id            = aws_vpc.dr_vpc[0].id
  cidr_block        = "10.2.1.0/24"
  availability_zone = data.aws_availability_zones.dr_azs[0].names[0]

  map_public_ip_on_launch = true

  tags = merge(local.tags, {
    Name                     = "${var.project_name}-dr-pub-subnet-1a"
    "kubernetes.io/role/elb" = "1"
  })
}

resource "aws_subnet" "dr_pub_subnet_1b" {
  count             = var.dr_enabled ? 1 : 0
  provider          = aws.dr
  vpc_id            = aws_vpc.dr_vpc[0].id
  cidr_block        = "10.2.2.0/24"
  availability_zone = data.aws_availability_zones.dr_azs[0].names[1]

  map_public_ip_on_launch = true

  tags = merge(local.tags, {
    Name                     = "${var.project_name}-dr-pub-subnet-1b"
    "kubernetes.io/role/elb" = "1"
  })
}

resource "aws_subnet" "dr_priv_subnet_1a" {
  count             = var.dr_enabled ? 1 : 0
  provider          = aws.dr
  vpc_id            = aws_vpc.dr_vpc[0].id
  cidr_block        = "10.2.3.0/24"
  availability_zone = data.aws_availability_zones.dr_azs[0].names[0]

  tags = merge(local.tags, {
    Name                              = "${var.project_name}-dr-priv-subnet-1a"
    "kubernetes.io/role/internal-elb" = "1"
  })
}

resource "aws_subnet" "dr_priv_subnet_1b" {
  count             = var.dr_enabled ? 1 : 0
  provider          = aws.dr
  vpc_id            = aws_vpc.dr_vpc[0].id
  cidr_block        = "10.2.4.0/24"
  availability_zone = data.aws_availability_zones.dr_azs[0].names[1]

  tags = merge(local.tags, {
    Name                              = "${var.project_name}-dr-priv-subnet-1b"
    "kubernetes.io/role/internal-elb" = "1"
  })
}

# --- Roteamento DR ---

resource "aws_eip" "dr_nat_eip" {
  count    = var.dr_enabled ? 1 : 0
  provider = aws.dr
  domain   = "vpc"
  tags     = merge(local.tags, { Name = "${var.project_name}-dr-nat-eip" })
}

resource "aws_nat_gateway" "dr_ngw" {
  count         = var.dr_enabled ? 1 : 0
  provider      = aws.dr
  allocation_id = aws_eip.dr_nat_eip[0].id
  subnet_id     = aws_subnet.dr_pub_subnet_1a[0].id
  tags          = merge(local.tags, { Name = "${var.project_name}-dr-ngw" })
  depends_on    = [aws_internet_gateway.dr_igw]
}

resource "aws_route_table" "dr_pub_rt" {
  count    = var.dr_enabled ? 1 : 0
  provider = aws.dr
  vpc_id   = aws_vpc.dr_vpc[0].id

  route {
    cidr_block = "0.0.0.0/0"
    gateway_id = aws_internet_gateway.dr_igw[0].id
  }

  tags = merge(local.tags, { Name = "${var.project_name}-dr-pub-rt" })
}

resource "aws_route_table" "dr_priv_rt" {
  count    = var.dr_enabled ? 1 : 0
  provider = aws.dr
  vpc_id   = aws_vpc.dr_vpc[0].id

  route {
    cidr_block     = "0.0.0.0/0"
    nat_gateway_id = aws_nat_gateway.dr_ngw[0].id
  }

  tags = merge(local.tags, { Name = "${var.project_name}-dr-priv-rt" })
}

resource "aws_route_table_association" "dr_pub_1a" {
  count          = var.dr_enabled ? 1 : 0
  provider       = aws.dr
  subnet_id      = aws_subnet.dr_pub_subnet_1a[0].id
  route_table_id = aws_route_table.dr_pub_rt[0].id
}

resource "aws_route_table_association" "dr_pub_1b" {
  count          = var.dr_enabled ? 1 : 0
  provider       = aws.dr
  subnet_id      = aws_subnet.dr_pub_subnet_1b[0].id
  route_table_id = aws_route_table.dr_pub_rt[0].id
}

resource "aws_route_table_association" "dr_priv_1a" {
  count          = var.dr_enabled ? 1 : 0
  provider       = aws.dr
  subnet_id      = aws_subnet.dr_priv_subnet_1a[0].id
  route_table_id = aws_route_table.dr_priv_rt[0].id
}

resource "aws_route_table_association" "dr_priv_1b" {
  count          = var.dr_enabled ? 1 : 0
  provider       = aws.dr
  subnet_id      = aws_subnet.dr_priv_subnet_1b[0].id
  route_table_id = aws_route_table.dr_priv_rt[0].id
}

# --- EKS DR ---

data "aws_iam_role" "labrole_dr" {
  count    = var.dr_enabled ? 1 : 0
  provider = aws.dr
  name     = "LabRole"
}

resource "aws_eks_cluster" "dr_eks_cluster" {
  count    = var.dr_enabled ? 1 : 0
  provider = aws.dr

  name     = "${var.project_name}-dr-cluster"
  role_arn = data.aws_iam_role.labrole_dr[0].arn
  version  = "1.34"

  vpc_config {
    subnet_ids = [
      aws_subnet.dr_pub_subnet_1a[0].id,
      aws_subnet.dr_pub_subnet_1b[0].id,
    ]
    endpoint_private_access = true
    endpoint_public_access  = true
  }

  tags = merge(local.tags, { Name = "${var.project_name}-dr-cluster" })
}

resource "aws_eks_node_group" "dr_eks_mng" {
  count    = var.dr_enabled ? 1 : 0
  provider = aws.dr

  cluster_name    = aws_eks_cluster.dr_eks_cluster[0].name
  node_group_name = "${var.project_name}-dr-node_group"
  node_role_arn   = data.aws_iam_role.labrole_dr[0].arn
  ami_type        = "AL2023_x86_64_STANDARD"
  instance_types  = ["t3.medium"]

  subnet_ids = [
    aws_subnet.dr_priv_subnet_1a[0].id,
    aws_subnet.dr_priv_subnet_1b[0].id,
  ]

  scaling_config {
    desired_size = 1
    max_size     = 2
    min_size     = 1
  }

  tags = merge(local.tags, { Name = "${var.project_name}-dr-nodegroup" })
}

# --- ECR Replication para região DR ---

resource "aws_ecr_replication_configuration" "dr_replication" {
  count = var.dr_enabled ? 1 : 0

  replication_configuration {
    rule {
      destination {
        region      = var.dr_region
        registry_id = data.aws_caller_identity.current.account_id
      }
    }
  }
}

data "aws_caller_identity" "current" {}

# --- RDS Read Replica donation-service na região DR ---
# Cross-region replica: garante RPO de 1h para dados de doações
resource "aws_db_instance" "dr_donation_replica" {
  count    = var.dr_enabled ? 1 : 0
  provider = aws.dr

  identifier          = "${var.project_name}-dr-donation-replica"
  replicate_source_db = module.resources.donation_db_arn
  instance_class      = "db.t3.micro"

  skip_final_snapshot = true
  publicly_accessible = false

  tags = merge(local.tags, { Name = "${var.project_name}-dr-donation-replica" })
}

# --- ArgoCD + Applications no cluster DR ---
# Instalado via local-exec após o node group DR estar pronto
resource "null_resource" "dr_argocd_setup" {
  count = var.dr_enabled ? 1 : 0

  triggers = {
    cluster_id = aws_eks_cluster.dr_eks_cluster[0].id
  }

  provisioner "local-exec" {
    command = <<-EOT
      set -e
      echo "Configurando kubeconfig para cluster DR..."
      aws eks update-kubeconfig \
        --name ${aws_eks_cluster.dr_eks_cluster[0].name} \
        --region ${var.dr_region} \
        --alias solidarytech-dr

      echo "Instalando ArgoCD no cluster DR..."
      helm repo add argo https://argoproj.github.io/argo-helm --force-update
      helm upgrade --install argocd argo/argo-cd \
        --version 5.51.6 \
        --namespace argocd \
        --create-namespace \
        --kube-context solidarytech-dr \
        --set dex.enabled=false \
        --set notifications.enabled=false \
        --set applicationset.enabled=false \
        --wait --timeout 8m

      echo "Configurando secret do repositório GitOps..."
      kubectl --context solidarytech-dr apply -f - <<'YAML'
      apiVersion: v1
      kind: Secret
      metadata:
        name: gitops-repo-secret
        namespace: argocd
        labels:
          argocd.argoproj.io/secret-type: repository
      stringData:
        type: git
        url: https://github.com/gabriel-cupertino/hackathon-gitops.git
        username: gabriel-cupertino
        password: ${var.gitops_pat}
      YAML

      echo "Criando ArgoCD Applications no cluster DR..."
      for SVC in ngo-service donation-service volunteer-service; do
        kubectl --context solidarytech-dr apply -f - <<YAML
      apiVersion: argoproj.io/v1alpha1
      kind: Application
      metadata:
        name: $SVC
        namespace: argocd
      spec:
        project: default
        source:
          repoURL: https://github.com/gabriel-cupertino/hackathon-gitops.git
          targetRevision: HEAD
          path: $SVC
        destination:
          server: https://kubernetes.default.svc
          namespace: $SVC
        syncPolicy:
          automated:
            prune: true
            selfHeal: true
          syncOptions:
            - CreateNamespace=true
      YAML
      done

      echo "DR cluster configurado com ArgoCD e 3 Applications."
    EOT
  }

  depends_on = [aws_eks_node_group.dr_eks_mng]
}

output "dr_cluster_name" {
  value       = var.dr_enabled ? aws_eks_cluster.dr_eks_cluster[0].name : "DR not enabled"
  description = "DR EKS cluster name in secondary region"
}

output "dr_activation_command" {
  value       = "terraform apply -var='dr_enabled=true' -var='dr_region=${var.dr_region}'"
  description = "Comando para ativar o ambiente DR"
}
