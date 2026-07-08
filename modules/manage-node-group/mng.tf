data "aws_iam_role" "labrole" {
  name = "LabRole"
}

resource "aws_launch_template" "eks_node" {
  name = "${var.project_name}-node-template"

  metadata_options {
    http_endpoint               = "enabled"
    http_tokens                 = "optional"
    http_put_response_hop_limit = 2
  }

  tags = var.tags
}

resource "aws_eks_node_group" "eks_manage_node_group" {
  cluster_name    = var.cluster_name
  node_group_name = "${var.project_name}-node_group"
  node_role_arn   = data.aws_iam_role.labrole.arn
  ami_type        = "AL2023_x86_64_STANDARD"
  instance_types  = ["t3.medium"]

  subnet_ids = [
    var.private_subnet_1a,
    var.private_subnet_1b
  ]

  tags = merge(
    var.tags,
    {
      Name = "${var.project_name}-nodegroup"
    }
  )

  scaling_config {
    desired_size = 2
    max_size     = 4
    min_size     = 1
  }

  launch_template {
    id      = aws_launch_template.eks_node.id
    version = aws_launch_template.eks_node.latest_version
  }
}

data "aws_security_groups" "nodegroup_sg" {
  depends_on = [aws_eks_node_group.eks_manage_node_group]

  filter {
    name   = "tag:eks:cluster-name"
    values = [var.cluster_name]
  }

  filter {
    name   = "tag:eks:nodegroup-name"
    values = [aws_eks_node_group.eks_manage_node_group.node_group_name]
  }
}
