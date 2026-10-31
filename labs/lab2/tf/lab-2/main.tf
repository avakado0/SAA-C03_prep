data "aws_availability_zones" "available" {
  state = "available"
}

data "aws_ami" "amazon_linux" {
  most_recent = true
  owners      = ["137112412989"]

  filter {
    name   = "name"
    values = ["al2023-ami-*-x86_64"]
  }

  filter {
    name   = "architecture"
    values = ["x86_64"]
  }

  filter {
    name   = "root-device-type"
    values = ["ebs"]
  }

  filter {
    name   = "virtualization-type"
    values = ["hvm"]
  }
}

locals {
  availability_zone = coalesce(
    var.availability_zone,
    data.aws_availability_zones.available.names[0]
  )

  common_tags = {
    Project   = var.project_name
    Lab       = "SAA-C03 Lab 2"
    ManagedBy = "Terraform"
    Purpose   = "Public EC2 + FastAPI networking lab"
  }
}

# ================================================================
# VPC
# ================================================================
# The VPC is the logical network boundary for the lab.
# It provides the address space but does NOT automatically provide
# Internet connectivity.

resource "aws_vpc" "lab" {
  cidr_block           = var.vpc_cidr
  enable_dns_support   = true
  enable_dns_hostnames = true

  tags = merge(local.common_tags, {
    Name = "${var.project_name}-vpc"
  })
}

# ================================================================
# INTERNET GATEWAY
# ================================================================
# The IGW is the VPC's connection point to the Internet.
#
# Important SAA distinction:
# An IGW alone does not make an EC2 public.
# The subnet must route Internet-bound traffic to the IGW and the
# instance must have a public IPv4 address for direct IPv4 Internet
# communication.

resource "aws_internet_gateway" "lab" {
  vpc_id = aws_vpc.lab.id

  tags = merge(local.common_tags, {
    Name = "${var.project_name}-igw"
  })
}

# ================================================================
# PUBLIC SUBNET
# ================================================================
# A subnet is an IP range inside the VPC.
#
# This subnet becomes "public" because its route table has:
#
#     0.0.0.0/0 -> Internet Gateway
#
# map_public_ip_on_launch is also enabled so instances launched
# here can receive public IPv4 addresses by default.

resource "aws_subnet" "public" {
  vpc_id                  = aws_vpc.lab.id
  cidr_block              = var.public_subnet_cidr
  availability_zone       = local.availability_zone
  map_public_ip_on_launch = true

  tags = merge(local.common_tags, {
    Name = "${var.project_name}-public-subnet"
    Tier = "Public"
  })
}

# ================================================================
# PUBLIC ROUTE TABLE
# ================================================================
# The VPC automatically has a local route for its own CIDR.
#
# We explicitly add:
#
#     0.0.0.0/0 -> Internet Gateway
#
# This tells AWS where Internet-bound IPv4 traffic should go.

resource "aws_route_table" "public" {
  vpc_id = aws_vpc.lab.id

  route {
    cidr_block = "0.0.0.0/0"
    gateway_id = aws_internet_gateway.lab.id
  }

  tags = merge(local.common_tags, {
    Name = "${var.project_name}-public-rt"
  })
}

# The subnet must actually use the public route table.
resource "aws_route_table_association" "public" {
  subnet_id      = aws_subnet.public.id
  route_table_id = aws_route_table.public.id
}

# ================================================================
# SECURITY GROUP
# ================================================================
# Security Groups are stateful virtual firewalls attached to ENIs.
#
# HTTP:
#     Internet -> TCP/80 -> EC2
#
# SSH:
#     Your IP -> TCP/22 -> EC2
#
# HTTP is intentionally public because this is a public web-server
# lab. SSH is restricted to the administrator's /32.

resource "aws_security_group" "web" {
  name        = "${var.project_name}-web-sg"
  description = "Security group for the public Lab 2 FastAPI EC2 instance"
  vpc_id      = aws_vpc.lab.id

  ingress {
    description = "HTTP from the Internet"
    from_port   = 80
    to_port     = 80
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  ingress {
    description = "SSH from administrator IP"
    from_port   = 22
    to_port     = 22
    protocol    = "tcp"
    cidr_blocks = [var.ssh_allowed_cidr]
  }

  egress {
    description = "Allow outbound IPv4 traffic"
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = merge(local.common_tags, {
    Name = "${var.project_name}-web-sg"
  })
}

# ================================================================
# EC2
# ================================================================
# The EC2 is placed in the public subnet, receives a public IPv4,
# uses the web Security Group, and bootstraps the FastAPI application.
#
# The complete public path is therefore:
#
# Internet
#   -> public IPv4
#   -> Internet Gateway
#   -> public subnet route
#   -> EC2 ENI
#   -> Security Group TCP/80
#   -> Uvicorn
#   -> FastAPI

resource "aws_instance" "web" {
  ami                         = data.aws_ami.amazon_linux.id
  instance_type               = var.instance_type
  subnet_id                   = aws_subnet.public.id
  vpc_security_group_ids      = [aws_security_group.web.id]
  associate_public_ip_address = true
  key_name                    = var.key_name

  user_data = file("${path.module}/app/user_data.sh")

  user_data_replace_on_change = true

  tags = merge(local.common_tags, {
    Name = "${var.project_name}-ec2"
    Role = "Web"
  })
}
