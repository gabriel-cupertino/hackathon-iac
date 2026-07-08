output "db_ngo_endpoint" {
  description = "RDS endpoint for ngo-service"
  value       = aws_db_instance.postgres_ngo_service.address
}

output "db_donation_endpoint" {
  description = "RDS endpoint for donation-service"
  value       = aws_db_instance.postgres_donation_service.address
}

output "dynamodb_volunteers_table" {
  description = "DynamoDB table name for volunteer-service"
  value       = aws_dynamodb_table.solidarytech_volunteers.name
}

output "donation_db_arn" {
  description = "ARN da instância RDS do donation-service para replicação cross-region"
  value       = aws_db_instance.postgres_donation_service.arn
}

output "donation_sqs_url" {
  description = "SQS queue URL for donation-service"
  value       = aws_sqs_queue.solidary_donations.url
}

output "ecr_ngo_url" {
  description = "ECR repository URL for ngo-service"
  value       = aws_ecr_repository.main["solidarytech_ngo-service"].repository_url
}

output "ecr_donation_url" {
  description = "ECR repository URL for donation-service"
  value       = aws_ecr_repository.main["solidarytech_donation-service"].repository_url
}

output "ecr_volunteer_url" {
  description = "ECR repository URL for volunteer-service"
  value       = aws_ecr_repository.main["solidarytech_volunteer-service"].repository_url
}
