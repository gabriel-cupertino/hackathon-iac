module "eks_network" {
  source       = "./modules/network"
  cidr_block   = var.cidr_block
  project_name = var.project_name
  tags         = local.tags
}

module "eks_cluster" {
  source           = "./modules/cluster"
  project_name     = var.project_name
  tags             = local.tags
  public_subnet_1a = module.eks_network.public_subnet_1a
  public_subnet_1b = module.eks_network.public_subnet_1b
}

module "eks_mng" {
  source            = "./modules/manage-node-group"
  project_name      = var.project_name
  tags              = local.tags
  cluster_name      = module.eks_cluster.cluster_name
  private_subnet_1a = module.eks_network.private_subnet_1a
  private_subnet_1b = module.eks_network.private_subnet_1b
  eks_cluster_sg    = module.eks_cluster.eks_cluster_sg
}

module "resources" {
  source            = "./modules/resources"
  project_name      = var.project_name
  tags              = local.tags
  vpc_id            = module.eks_network.vpc_id
  vpc_cidr          = module.eks_network.vpc_cidr
  private_subnet_1a = module.eks_network.private_subnet_1a
  private_subnet_1b = module.eks_network.private_subnet_1b
  db_user           = var.db_user
  db_password       = var.db_password
}

module "kubernetes" {
  source                    = "./modules/kubernetes"
  project_name              = var.project_name
  tags                      = local.tags
  db_user                   = var.db_user
  db_password               = var.db_password
  db_ngo_endpoint           = module.resources.db_ngo_endpoint
  db_donation_endpoint      = module.resources.db_donation_endpoint
  dynamodb_volunteers_table = module.resources.dynamodb_volunteers_table
  donation_sqs_url          = module.resources.donation_sqs_url
  depends_on                = [module.eks_cluster, module.eks_mng]
}
