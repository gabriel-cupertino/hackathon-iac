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
# Nota: cross-region read replica requer snapshot da instância primária

output "dr_cluster_name" {
  value       = var.dr_enabled ? aws_eks_cluster.dr_eks_cluster[0].name : "DR not enabled"
  description = "DR EKS cluster name in secondary region"
}

output "dr_activation_command" {
  value       = "terraform apply -var='dr_enabled=true' -var='dr_region=${var.dr_region}'"
  description = "Comando para ativar o ambiente DR"
}
