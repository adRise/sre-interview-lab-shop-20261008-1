provider "aws" {
  region = "us-east-2"

  default_tags {
    tags = {
      Service = "sre-interview-lab"
      Team    = "platform-sre"
      Org     = "tubi"
    }
  }
}

# The network comes from the lab platform.
data "aws_vpc" "lab" {
  tags = { Name = "sre-interview-lab" }
}

data "aws_subnets" "private" {
  filter {
    name   = "vpc-id"
    values = [data.aws_vpc.lab.id]
  }
  # The primary and the standby live in these two zones.
  filter {
    name   = "availability-zone"
    values = ["us-east-2a", "us-east-2b"]
  }
  tags = { "kubernetes.io/role/internal-elb" = "1" }
}

# Security group of the shop nodes.
data "aws_security_group" "nodes" {
  vpc_id = data.aws_vpc.lab.id
  name   = "lab-nodes"
}

resource "random_password" "db" {
  length  = 32
  special = false
}

resource "aws_db_subnet_group" "shop" {
  name       = "shop-db"
  subnet_ids = data.aws_subnets.private.ids
}

resource "aws_security_group" "db" {
  name        = "shop-db"
  description = "PostgreSQL for shop"
  vpc_id      = data.aws_vpc.lab.id
  tags        = { Name = "shop-db" }
}

resource "aws_vpc_security_group_ingress_rule" "db_from_nodes" {
  security_group_id            = aws_security_group.db.id
  description                  = "PostgreSQL from shop nodes"
  ip_protocol                  = "tcp"
  from_port                    = 5432
  to_port                      = 5432
  referenced_security_group_id = data.aws_security_group.nodes.id
}

resource "aws_db_parameter_group" "shop" {
  name   = "shop-db"
  family = "postgres17"
}

resource "aws_db_instance" "shop" {
  identifier     = "shop-db"
  engine         = "postgres"
  engine_version = "17"
  instance_class = "db.t4g.micro"

  allocated_storage = 20
  storage_type      = "gp3"
  storage_encrypted = true

  multi_az               = true
  db_subnet_group_name   = aws_db_subnet_group.shop.name
  vpc_security_group_ids = [aws_security_group.db.id]
  parameter_group_name   = aws_db_parameter_group.shop.name
  publicly_accessible    = false

  db_name  = "shop"
  username = "shop"
  password = random_password.db.result

  backup_retention_period    = 1
  copy_tags_to_snapshot      = true
  auto_minor_version_upgrade = false
  skip_final_snapshot        = true
  deletion_protection        = false
}

output "db_address" {
  description = "RDS endpoint host name."
  value       = aws_db_instance.shop.address
}

output "db_password" {
  description = "Password of the shop user."
  value       = random_password.db.result
  sensitive   = true
}
