data "aws_region" "current" {}

# ngo-service: senha do banco (separada do host para rotação independente)
resource "kubernetes_secret_v1" "ngo_db_secret" {
  depends_on = [kubernetes_namespace_v1.ngo-service]

  metadata {
    name      = "ngo-db-secret"
    namespace = "ngo-service"
  }

  data = {
    POSTGRES_PASSWORD = var.db_password
  }

  type = "Opaque"
}

# donation-service: senha do banco
resource "kubernetes_secret_v1" "donation_db_secret" {
  depends_on = [kubernetes_namespace_v1.donation-service]

  metadata {
    name      = "donation-db-secret"
    namespace = "donation-service"
  }

  data = {
    POSTGRES_PASSWORD = var.db_password
  }

  type = "Opaque"
}

# ngo-service: fornece POSTGRES_HOST, DATABASE_URL para o init job e app
resource "kubernetes_secret_v1" "ngo_db_secret_host" {
  depends_on = [kubernetes_namespace_v1.ngo-service]

  metadata {
    name      = "ngo-db-secret-host"
    namespace = "ngo-service"
  }

  data = {
    POSTGRES_HOST = var.db_ngo_endpoint
    POSTGRES_USER = var.db_user
    POSTGRES_DB   = "ngo_db"
    DATABASE_URL  = "postgresql://${var.db_user}:${var.db_password}@${var.db_ngo_endpoint}:5432/ngo_db"
  }

  type = "Opaque"
}

# donation-service: fornece POSTGRES_HOST, DATABASE_URL, AWS_SQS_URL e AWS_REGION
resource "kubernetes_secret_v1" "donation_db_secret_host" {
  depends_on = [kubernetes_namespace_v1.donation-service]

  metadata {
    name      = "donation-db-secret-host"
    namespace = "donation-service"
  }

  data = {
    POSTGRES_HOST = var.db_donation_endpoint
    POSTGRES_USER = var.db_user
    POSTGRES_DB   = "donation_db"
    DATABASE_URL  = "postgresql://${var.db_user}:${var.db_password}@${var.db_donation_endpoint}:5432/donation_db"
    AWS_SQS_URL   = var.donation_sqs_url
    AWS_REGION    = data.aws_region.current.id
  }

  type = "Opaque"
}

# volunteer-service: fornece AWS_DYNAMODB_TABLE e AWS_REGION
resource "kubernetes_secret_v1" "volunteer_db_secret_host" {
  depends_on = [kubernetes_namespace_v1.volunteer-service]

  metadata {
    name      = "volunteer-db-secret-host"
    namespace = "volunteer-service"
  }

  data = {
    AWS_DYNAMODB_TABLE = var.dynamodb_volunteers_table
    AWS_REGION         = data.aws_region.current.id
  }

  type = "Opaque"
}
