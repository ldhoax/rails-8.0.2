output "ec2_public_ip" {
  value = aws_eip.your_ec2_eip.public_ip
}

output "ec2_public_dns" {
  value = aws_eip.your_ec2_eip.public_dns
}

output "rds_endpoint" {
  value = aws_db_instance.your_rds.endpoint
}

output "rds_port" {
  value = 5432
}

output "rds_username" {
  value = var.rds_username
}

output "rds_password" {
  value     = var.rds_password
  sensitive = true
}

output "rds_database_name" {
  value = var.rds_database_name
}

output "redis_endpoint" {
  value = aws_elasticache_cluster.your_redis.cache_nodes[0].address
}

output "ecr_repository_url" {
  value = aws_ecr_repository.your_ecr.repository_url
}

output "s3_bucket_name" {
  value = aws_s3_bucket.your_s3.bucket
}

output "s3_bucket_arn" {
  value = aws_s3_bucket.your_s3.arn
}

output "aws_region" {
  value = var.aws_region
}

output "aws_access_key" {
  value     = var.aws_access_key
  sensitive = true
}

output "aws_secret_key" {
  value     = var.aws_secret_key
  sensitive = true
}

output "ec2_instance_type" {
  value = var.ec2_instance_type
}

output "ec2_key_name" {
  value = var.ec2_key_name
}

output "ec2_ami_id" {
  value = var.ec2_ami_id
}

output "rds_storage_size" {
  value = var.rds_storage_size
}

output "redis_node_type" {
  value = var.redis_node_type
}

output "redis_engine_version" {
  value = var.redis_engine_version
}

output "vpc_cidr_block" {
  value = var.vpc_cidr_block
}

output "vpc_public_subnet_cidr" {
  value = var.vpc_public_subnet_cidr
}

output "vpc_private_subnet_cidr" {
  value = var.vpc_private_subnet_cidr
}

output "vpc_availability_zone" {
  value = var.vpc_availability_zone
}

output "environment" {
  value = var.environment
}
