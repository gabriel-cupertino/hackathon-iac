variable "project_name" {
  type        = string
  description = "Project name to be used to name the resources (name tag)"
}

variable "tags" {
  type        = map(any)
  description = "Tags to be added to AWS resources"
}

variable "cluster_name" {
  type        = string
  description = "Cluster name to integrate MNG to cluster"
}

variable "private_subnet_1a" {
  type        = string
  description = "Subnet to create EKS Managed Node Group AZ-1a"
}

variable "private_subnet_1b" {
  type        = string
  description = "Subnet to create EKS Managed Node Group AZ-1b"
}

variable "eks_cluster_sg" {
  type        = string
  description = "Cluster SG to ingress rules"
}
