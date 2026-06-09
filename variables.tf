variable "cidr_block" {
  type        = string
  description = "Networking CIDR block to be used for the VPC"
  default     = "10.1.0.0/16"
}

variable "project_name" {
  type        = string
  description = "Project name to be used to name the resources (name tag)"
  default     = "solidarytech"
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

variable "gitops_pat" {
  type        = string
  description = "GitHub Personal Access Token with read access to the GitOps repository"
  sensitive   = true
}

variable "datadog_api_key" {
  type        = string
  description = "Datadog API Key for OTel Collector and APM"
  sensitive   = true
}

variable "opsgenie_api_key" {
  type        = string
  description = "OpsGenie API Key for AlertManager integration"
  sensitive   = true
}

variable "slack_webhook_url" {
  type        = string
  description = "Slack Incoming Webhook URL for AlertManager notifications"
  sensitive   = true
}

variable "dr_enabled" {
  type        = bool
  description = "Enable Disaster Recovery warm standby in secondary region"
  default     = false
}

variable "dr_region" {
  type        = string
  description = "Secondary AWS region for Disaster Recovery"
  default     = "us-west-2"
}
