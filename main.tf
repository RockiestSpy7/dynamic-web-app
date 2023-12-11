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

# create alb module
module "application_load_balancer" {
  source = "git@github.com:RockiestSpy7/terraform-modules.git//alb"
  # alb variables
  project_name              = local.project_name
  environment               = local.environment
  alb_security_group_id     = module.security-groups.alb_security_group_id
  private_app_subnet_az1_id = module.vpc.private_app_subnet_az1_id
  private_app_subnet_az2_id = module.vpc.private_app_subnet_az2_id
  target_type               = var.target_type
  vpc_id                    = module.vpc.vpc_id
  certificate_arn           = module.ssl_certificate.certificate_arn
}

# create s3 bucket module
module "s3_bucket" {
  source = "git@github.com:RockiestSpy7/terraform-modules.git//s3"
  # s3 variables
  project_name         = local.project_name
  env_file_bucket_name = var.env_file_bucket_name
  env_file_name        = var.env_file_name
}

# create ecs task execution role module
module "ecs_task_execution_role" {
  source = "git@github.com:RockiestSpy7/terraform-modules.git//iam-role"
  # ecs task execution role variables
  project_name         = local.project_name
  env_file_bucket_name = module.s3_bucket.env_file_bucket_name
  environment          = local.environment
}

# create ecs cluster, task definition and service
module "ecs" {
  source = "git@github.com:RockiestSpy7/terraform-modules.git//ecs"
  # ecs cluster variables
  project_name                 = local.project_name
  environment                  = local.environment
  ecs_task_execution_role_arn  = module.ecs_task_execution_role.ecs_task_execution_role_arn
  architecture                 = var.architecture
  container_image              = var.container_image
  env_file_bucket_name         = module.s3_bucket.env_file_bucket_name
  env_file_name                = module.s3_bucket.env_file_name
  region                       = local.region
  private_app_subnet_az1_id    = module.vpc.private_app_subnet_az1_id
  private_app_subnet_az2_id    = module.vpc.private_app_subnet_az2_id
  app_server_security_group_id = module.security-groups.app_server_security_group_id
  alb_target_group_arn         = module.application_load_balancer.alb_target_group_arn
}

# create asg module
module "asg_ecs" {
  source = "git@github.com:RockiestSpy7/terraform-modules.git//asg-ecs"
  # asg variables
  project_name = local.project_name
  environment  = local.environment
  ecs_service  = module.ecs.ecs_service
}

# create record set in route-53 module
module "route_53" {
  source = "git@github.com:RockiestSpy7/terraform-modules.git//route-53"
  # route 53 variables
  domain_name                        = module.ssl_certificate.domain_name
  record_name                        = var.record_name
  application_load_balancer_dns_name = module.application_load_balancer.application_load_balancer_dns_name
  application_load_balancer_zone_id  = module.application_load_balancer.application_load_balancer_zone_id
}

# outputs the url of my website
output "website_url" {
  value = join("", ["https://", var.record_name, ".", var.domain_name])
}