variable "project_repos" {
  type = set(string)
  default = [
    "solidarytech_ngo-service",
    "solidarytech_donation-service",
    "solidarytech_volunteer-service",
  ]
}

resource "aws_ecr_repository" "main" {
  for_each = var.project_repos

  name                 = each.value
  image_tag_mutability = "MUTABLE"
  force_delete         = true

  image_scanning_configuration {
    scan_on_push = true
  }

  tags = merge(
    var.tags,
    {
      Name = each.value
    }
  )
}

resource "aws_ecr_lifecycle_policy" "main" {
  for_each = aws_ecr_repository.main

  repository = each.value.name

  policy = jsonencode({
    rules = [
      {
        rulePriority = 1
        description  = "Manter apenas as últimas 5 imagens"
        selection = {
          tagStatus   = "any"
          countType   = "imageCountMoreThan"
          countNumber = 5
        }
        action = {
          type = "expire"
        }
      }
    ]
  })
}
