locals {
  region       = var.region
  project_name = var.project_name
  environment  = var.environment
}

# create vpc module
module "vpc" {
  source = "git@github.com:RockiestSpy7/terraform-modules.git//vpc"
  # environment variables
  region       = local.region
  project_name = local.project_name
  environment  = local.environment

  # vpc variables
  vpc_cider                    = var.vpc_cider
  public_subnet_az1_cidr       = var.public_subnet_az1_cidr
  public_subnet_az2_cidr       = var.public_subnet_az2_cidr
  private_app_subnet_az1_cidr  = var.private_app_subnet_az1_cidr
  private_app_subnet_az2_cidr  = var.private_app_subnet_az2_cidr
  private_data_subnet_az1_cidr = var.private_data_subnet_az1_cidr
  private_data_subnet_az2_cidr = var.private_data_subnet_az2_cidr
}

# create nat-gateway module
module "nat-gateway" {
  source = "git@github.com:RockiestSpy7/terraform-modules.git//nat-gateway"
  # nat-gateway variables
  project_name               = local.project_name
  environment                = local.environment
  public_subnet_az1_id       = module.vpc.public_subnet_az1_id
  internet_gateway           = module.vpc.internet_gateway
  public_subnet_az2_id       = module.vpc.public_subnet_az2_id
  vpc_id                     = module.vpc.vpc_id
  private_app_subnet_az1_id  = module.vpc.private_app_subnet_az1_id
  private_data_subnet_az1_id = module.vpc.private_data_subnet_az1_id
  private_app_subnet_az2_id  = module.vpc.private_app_subnet_az2_id
  private_data_subnet_az2_id = module.vpc.private_data_subnet_az2_id
}

# create security-group module
module "security-groups" {
  source = "git@github.com:RockiestSpy7/terraform-modules.git//security-groups"
  # security-group variables
  project_name = local.project_name
  environment  = local.environment
  vpc_id       = module.vpc.vpc_id
  ssh_id       = var.ssh_id
}

# create rds module
module "rds" {
  source = "git@github.com:RockiestSpy7/terraform-modules.git//rds"
  # rds variables
  project_name                 = local.project_name
  environment                  = local.environment
  private_data_subnet_az1_id   = module.vpc.private_data_subnet_az1_id
  private_data_subnet_az2_id   = module.vpc.private_data_subnet_az2_id
  database_snapshot_identifier = var.database_snapshot_identifier
  database_instance_class      = var.database_instance_class
  availability_zone_1          = module.vpc.availability_zone_1
  database_instance_identifier = var.database_instance_identifier
  multi_az_deployment          = var.multi_az_deployment
  database_security_group_id   = module.security-groups.database_security_group_id
}

# request ssl certificate
module "ssl_certificate" {
  source = "git@github.com:RockiestSpy7/terraform-modules.git//acm"
  # acm variables
  domain_name       = var.domain_name
  alternative_names = var.alternative_names
}