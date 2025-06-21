module "vpc" {
  source = "terraform-aws-modules/vpc/aws"

  name = "my-vpc"
  cidr = "10.0.0.0/16"

  azs             = ["us-east-1a", "us-east-1b"]
  private_subnets = ["10.0.1.0/24", "10.0.2.0/24"]
  public_subnets  = ["10.0.101.0/24", "10.0.102.0/24"]

  enable_vpn_gateway = false

  enable_nat_gateway  = true
  single_nat_gateway  = true
  reuse_nat_ips       = true # <= Skip creation of EIPs for the NAT Gateways
  external_nat_ip_ids = aws_eip.nat.*.id

  tags = {
    Terraform   = "true"
    Environment = "dev"
  }
}

resource "aws_eip" "nat" {
  count  = 1
  domain = "vpc"
}

resource "aws_db_subnet_group" "private_subnet_group_001" {
  name       = "prv_subnet_group"
  subnet_ids = module.vpc.private_subnets

  tags = {
    Name = "Private Subnet Group for MySQL RDS DB"
  }
}



module "db" {
  source = "terraform-aws-modules/rds/aws"

  identifier = "database-instance-00x"

  engine               = "mysql"
  engine_version       = "8.0"
  family               = "mysql8.0" # DB parameter group
  major_engine_version = "8.0"      # DB option group
  instance_class       = "db.t4g.micro"

  allocated_storage     = 10
  max_allocated_storage = 20

  db_name  = "mydb"
  username = "admin"
  port     = 3306

  multi_az               = true
  db_subnet_group_name   = aws_db_subnet_group.private_subnet_group_001.name
  vpc_security_group_ids = [module.security_group.security_group_id]

  maintenance_window              = "Mon:00:00-Mon:03:00"
  backup_window                   = "03:00-06:00"
  enabled_cloudwatch_logs_exports = ["general"]
  create_cloudwatch_log_group     = true

  skip_final_snapshot = true
  deletion_protection = false

  # performance_insights_enabled          = true
  # performance_insights_retention_period = 7

  monitoring_interval    = "30"
  monitoring_role_name   = "MyRDSMonitoringRole"
  create_monitoring_role = true

  parameters = [
    {
      name  = "character_set_client"
      value = "utf8mb4"
    },
    {
      name  = "character_set_server"
      value = "utf8mb4"
    }
  ]

  tags = local.tags
  db_instance_tags = {
    "Sensitive" = "high"
  }
  db_option_group_tags = {
    "Sensitive" = "low"
  }
  db_parameter_group_tags = {
    "Sensitive" = "low"
  }
  db_subnet_group_tags = {
    "Sensitive" = "high"
  }
  cloudwatch_log_group_tags = {
    "Sensitive" = "high"
  }
}



module "security_group" {
  source  = "terraform-aws-modules/security-group/aws"
  version = "~> 5.0"

  name        = "rds_db_mysql_sec_grp_001"
  description = "Complete MySQL example security group"
  vpc_id      = module.vpc.vpc_id

  # ingress
  ingress_with_cidr_blocks = [
    {
      from_port   = 3306
      to_port     = 3306
      protocol    = "tcp"
      description = "MySQL access from within VPC"
      cidr_blocks = module.vpc.vpc_cidr_block
    },
  ]

  tags = local.tags
}

locals {
  name   = "complete-mysql"
  tags = {
    Name       = local.name
    Example    = local.name
    Repository = "https://github.com/terraform-aws-modules/terraform-aws-rds"
  }
}