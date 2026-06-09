data "aws_iam_role" "labrole" {
  name = "LabRole"
}

resource "aws_eks_cluster" "eks_cluster" {
  name     = "${var.project_name}-cluster"
  role_arn = data.aws_iam_role.labrole.arn
  version  = "1.34"

  vpc_config {
    subnet_ids = [
      var.public_subnet_1a,
      var.public_subnet_1b
    ]
    endpoint_private_access = true
    endpoint_public_access  = true
  }

  tags = merge(
    var.tags,
    {
      Name = "${var.project_name}-cluster"
    }
  )
}

data "aws_eks_cluster" "eks_cluster" {
  name = aws_eks_cluster.eks_cluster.name
}
