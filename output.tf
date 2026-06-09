output "cluster_name" {
  description = "EKS cluster name"
  value       = module.eks_cluster.cluster_name
}

output "ecr_ngo_service_url" {
  description = "ECR URL for ngo-service"
  value       = module.resources.ecr_ngo_url
}

output "ecr_donation_service_url" {
  description = "ECR URL for donation-service"
  value       = module.resources.ecr_donation_url
}

output "ecr_volunteer_service_url" {
  description = "ECR URL for volunteer-service"
  value       = module.resources.ecr_volunteer_url
}

output "rds_ngo_endpoint" {
  description = "RDS endpoint for ngo-service"
  value       = module.resources.db_ngo_endpoint
}

output "rds_donation_endpoint" {
  description = "RDS endpoint for donation-service"
  value       = module.resources.db_donation_endpoint
}

output "sqs_donations_url" {
  description = "SQS URL for donation events"
  value       = module.resources.donation_sqs_url
}

output "dynamodb_volunteers_table" {
  description = "DynamoDB table for volunteers"
  value       = module.resources.dynamodb_volunteers_table
}
