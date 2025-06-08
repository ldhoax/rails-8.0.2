resource "aws_vpc" "your_vpc" {
  cidr_block           = var.vpc_cidr_block
  enable_dns_hostnames = true
  enable_dns_support   = true

  tags = {
    Name = "your-staging-vpc"
  }
}

resource "aws_subnet" "your_vpc_public_subnet" {
  vpc_id                  = aws_vpc.your_vpc.id
  cidr_block              = var.vpc_public_subnet_cidr
  map_public_ip_on_launch = true
  availability_zone       = var.vpc_availability_zone

  tags = {
    Name = "your-staging-public-subnet"
  }
}

resource "aws_subnet" "your_vpc_private_subnet_a" {
  vpc_id            = aws_vpc.your_vpc.id
  cidr_block        = var.vpc_private_subnet_cidr
  availability_zone = var.vpc_availability_zone

  tags = {
    Name = "your-staging-private-subnet-a"
  }
}

resource "aws_subnet" "your_vpc_private_subnet_b" {
  vpc_id            = aws_vpc.your_vpc.id
  cidr_block        = "10.0.3.0/24"
  availability_zone = "us-east-1b"

  tags = {
    Name = "your-staging-private-subnet-b"
  }
}

resource "aws_internet_gateway" "your_vpc_igw" {
  vpc_id = aws_vpc.your_vpc.id

  tags = {
    Name = "your-staging-igw"
  }
}

resource "aws_route_table" "your_vpc_public_rt" {
  vpc_id = aws_vpc.your_vpc.id

  route {
    cidr_block = "0.0.0.0/0"
    gateway_id = aws_internet_gateway.your_vpc_igw.id
  }

  tags = {
    Name = "your-staging-public-rt"
  }
}

resource "aws_route_table" "your_vpc_private_rt" {
  vpc_id = aws_vpc.your_vpc.id

  tags = {
    Name = "your-staging-private-rt"
  }
}

resource "aws_route_table_association" "your_vpc_public_rta" {
  subnet_id      = aws_subnet.your_vpc_public_subnet.id
  route_table_id = aws_route_table.your_vpc_public_rt.id
}

resource "aws_route_table_association" "your_vpc_private_rta_a" {
  subnet_id      = aws_subnet.your_vpc_private_subnet_a.id
  route_table_id = aws_route_table.your_vpc_private_rt.id
}

resource "aws_route_table_association" "your_vpc_private_rta_b" {
  subnet_id      = aws_subnet.your_vpc_private_subnet_b.id
  route_table_id = aws_route_table.your_vpc_private_rt.id
}
