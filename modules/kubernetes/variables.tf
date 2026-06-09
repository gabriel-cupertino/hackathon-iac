variable "project_name" {
  type        = string
  description = "Project name"
}

variable "tags" {
  type        = map(any)
  description = "Tags to be added to AWS resources"
}

variable "db_user" {
  type        = string
  description = "RDS master username"
}

variable "db_password" {
  type        = string
  description = "RDS master password"
  sensitive   = true
}

variable "db_ngo_endpoint" {
  type        = string
  description = "RDS endpoint for ngo-service"
}

variable "db_donation_endpoint" {
  type        = string
  description = "RDS endpoint for donation-service"
}

variable "dynamodb_volunteers_table" {
  type        = string
  description = "DynamoDB table name for volunteer-service"
}

variable "donation_sqs_url" {
  type        = string
  description = "SQS URL for donation-service"
}
