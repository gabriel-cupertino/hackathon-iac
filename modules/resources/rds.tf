resource "aws_security_group" "rds_sg" {
  name        = "${var.project_name}-rds-sg"
  description = "Allow PostgreSQL from inside VPC"
  vpc_id      = var.vpc_id

  ingress {
    from_port   = 5432
    to_port     = 5432
    protocol    = "tcp"
    cidr_blocks = [var.vpc_cidr]
  }

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = merge(
    var.tags,
    {
      Name = "${var.project_name}-rds-sg"
    }
  )
}

resource "aws_db_subnet_group" "rds_subnetgroup" {
  name       = "${var.project_name}-rds-subnetgroup"
  subnet_ids = [var.private_subnet_1a, var.private_subnet_1b]

  tags = merge(
    var.tags,
    {
      Name = "${var.project_name}-rds-subnetgroup"
    }
  )
}

# RDS ngo-service
resource "aws_db_instance" "postgres_ngo_service" {
  identifier = "${var.project_name}-ngo-db"

  engine            = "postgres"
  engine_version    = "15"
  instance_class    = "db.t3.micro"
  allocated_storage = 20

  db_name  = "ngo_db"
  username = var.db_user
  password = var.db_password

  db_subnet_group_name   = aws_db_subnet_group.rds_subnetgroup.name
  vpc_security_group_ids = [aws_security_group.rds_sg.id]

  skip_final_snapshot = true
  publicly_accessible = false

  tags = merge(
    var.tags,
    {
      Name = "${var.project_name}-ngo-service-rds"
    }
  )
}

# RDS donation-service (Hot Path — instância dedicada)
resource "aws_db_instance" "postgres_donation_service" {
  identifier = "${var.project_name}-donation-db"

  engine            = "postgres"
  engine_version    = "15"
  instance_class    = "db.t3.micro"
  allocated_storage = 20

  db_name  = "donation_db"
  username = var.db_user
  password = var.db_password

  db_subnet_group_name   = aws_db_subnet_group.rds_subnetgroup.name
  vpc_security_group_ids = [aws_security_group.rds_sg.id]

  skip_final_snapshot      = true
  publicly_accessible      = false
  backup_retention_period  = 7
  backup_window            = "03:00-04:00"
  maintenance_window       = "Mon:04:00-Mon:05:00"

  tags = merge(
    var.tags,
    {
      Name = "${var.project_name}-donation-service-rds"
    }
  )
}
