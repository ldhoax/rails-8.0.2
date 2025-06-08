terraform {
  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 5.0"
    }
  }
}

provider "aws" {
  region     = var.aws_region
  access_key = var.aws_access_key
  secret_key = var.aws_secret_key
}

resource "tls_private_key" "your_ec2_key" {
  algorithm = "RSA"
  rsa_bits  = 4096
}

resource "aws_key_pair" "your_ec2_key" {
  key_name   = var.ec2_key_name
  public_key = tls_private_key.your_ec2_key.public_key_openssh
}

resource "local_file" "your_ec2_private_key" {
  content         = tls_private_key.your_ec2_key.private_key_pem
  filename        = "${path.module}/${var.ec2_key_name}.pem"
  file_permission = "0400"
}

resource "aws_security_group" "your_ec2_sg" {
  name        = "your-ec2-sg"
  description = "Security group for your EC2 instance"
  vpc_id      = aws_vpc.your_vpc.id

  ingress {
    from_port   = 22
    to_port     = 22
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  ingress {
    from_port   = 80
    to_port     = 80
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  ingress {
    from_port   = 443
    to_port     = 443
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  ingress {
    from_port   = 19999
    to_port     = 19999
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }
}

resource "aws_security_group" "your_rds_sg" {
  name        = "your-rds-sg"
  description = "Security group for RDS"
  vpc_id      = aws_vpc.your_vpc.id

  ingress {
    from_port       = 5432
    to_port         = 5432
    protocol        = "tcp"
    security_groups = [aws_security_group.your_ec2_sg.id]
  }
}

resource "aws_security_group" "your_cache_sg" {
  name        = "your-cache-sg"
  description = "Security group for ElastiCache"
  vpc_id      = aws_vpc.your_vpc.id

  ingress {
    from_port       = 6379
    to_port         = 6379
    protocol        = "tcp"
    security_groups = [aws_security_group.your_ec2_sg.id]
  }
}

resource "aws_db_subnet_group" "your_rds_subnet" {
  name       = "your-rds-subnet"
  subnet_ids = [aws_subnet.your_vpc_private_subnet_a.id, aws_subnet.your_vpc_private_subnet_b.id]
  tags = {
    Name = "your-staging-rds-subnet"
  }
}

resource "aws_db_instance" "your_rds" {
  identifier          = "your-rds"
  engine              = "postgres"
  engine_version      = "17.2"
  instance_class      = "db.t3.micro"
  allocated_storage   = var.rds_storage_size
  storage_type        = "gp2"
  db_name             = var.rds_database_name
  username            = var.rds_username
  password            = var.rds_password
  skip_final_snapshot = true
  publicly_accessible = false

  vpc_security_group_ids = [aws_security_group.your_rds_sg.id]
  db_subnet_group_name   = aws_db_subnet_group.your_rds_subnet.name
}

resource "aws_elasticache_subnet_group" "your_redis_subnet" {
  name       = "your-redis-subnet"
  subnet_ids = [aws_subnet.your_vpc_private_subnet_a.id, aws_subnet.your_vpc_private_subnet_b.id]
}

resource "aws_elasticache_cluster" "your_redis" {
  cluster_id           = "your-redis"
  engine               = "redis"
  node_type            = var.redis_node_type
  num_cache_nodes      = 1
  parameter_group_name = "default.redis7"
  engine_version       = var.redis_engine_version
  port                 = 6379
  security_group_ids   = [aws_security_group.your_cache_sg.id]
  subnet_group_name    = aws_elasticache_subnet_group.your_redis_subnet.name
}

resource "aws_instance" "your_ec2" {
  ami           = var.ec2_ami_id
  instance_type = var.ec2_instance_type
  key_name      = aws_key_pair.your_ec2_key.key_name
  subnet_id     = aws_subnet.your_vpc_public_subnet.id

  vpc_security_group_ids = [aws_security_group.your_ec2_sg.id]

  tags = {
    Name = "your-staging-ec2"
  }
}

resource "aws_eip" "your_ec2_eip" {
  instance = aws_instance.your_ec2.id
  domain   = "vpc"

  tags = {
    Name = "your-staging-eip"
  }
}

resource "aws_ecr_repository" "your_ecr" {
  name                 = "your-api"
  image_tag_mutability = "MUTABLE"
  force_delete         = true

  image_scanning_configuration {
    scan_on_push = true
  }

  tags = {
    Name = "your-api-ecr"
  }
}

resource "aws_ecr_lifecycle_policy" "your_ecr_policy" {
  repository = aws_ecr_repository.your_ecr.name

  policy = jsonencode({
    rules = [
      {
        rulePriority = 1
        description  = "Keep last 5 images"
        selection = {
          tagStatus   = "any"
          countType   = "imageCountMoreThan"
          countNumber = 5
        }
        action = {
          type = "expire"
        }
      }
    ]
  })
}

resource "aws_s3_bucket" "your_s3" {
  bucket = "your-api-storage-${var.environment}"

  tags = {
    Name = "your-api-s3"
  }
}

resource "aws_s3_bucket_versioning" "your_s3_versioning" {
  bucket = aws_s3_bucket.your_s3.id
  versioning_configuration {
    status = "Enabled"
  }
}

resource "aws_s3_bucket_server_side_encryption_configuration" "your_s3_encryption" {
  bucket = aws_s3_bucket.your_s3.id

  rule {
    apply_server_side_encryption_by_default {
      sse_algorithm = "AES256"
    }
  }
}

resource "aws_s3_bucket_public_access_block" "your_s3_access" {
  bucket = aws_s3_bucket.your_s3.id

  block_public_acls       = true
  block_public_policy     = true
  ignore_public_acls      = true
  restrict_public_buckets = true
}
