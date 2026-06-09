variable "project_name" {
  type        = string
  description = "Project name to be used to name the resources (name tag)"
}

variable "tags" {
  type        = map(any)
  description = "Tags to be added to AWS resources"
}

variable "vpc_id" {
  type        = string
  description = "VPC ID for security groups"
}

variable "vpc_cidr" {
  type        = string
  description = "CIDR from VPC for RDS security group ingress"
}

variable "private_subnet_1a" {
  type        = string
  description = "Private subnet AZ-1a for RDS subnet group"
}

variable "private_subnet_1b" {
  type        = string
  description = "Private subnet AZ-1b for RDS subnet group"
}

variable "db_user" {
  type        = string
  description = "Master username for RDS"
}

variable "db_password" {
  type        = string
  description = "Master password for RDS"
  sensitive   = true
}
