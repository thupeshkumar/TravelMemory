terraform {
  required_version = ">= 1.5.0"
  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = ">= 5.0"
    }
  }
}

provider "aws" {
  region = var.region
}

# ---------------------------
# Default VPC + Subnet + IGW
# ---------------------------
# Use the default VPC
data "aws_vpc" "default" {
  default = true
}

# Get all subnets in the default VPC and pick the first one (default subnets are public)
data "aws_subnets" "default_vpc_subnets" {
  filter {
    name   = "vpc-id"
    values = [data.aws_vpc.default.id]
  }
}

# Try to fetch the IGW already attached to default VPC (default VPC normally has one)
data "aws_internet_gateway" "default_vpc_igw" {
  filter {
    name   = "attachment.vpc-id"
    values = [data.aws_vpc.default.id]
  }
}

# Create a dedicated route table with a default route to the IGW
resource "aws_route_table" "public" {
  vpc_id = data.aws_vpc.default.id

  route {
    cidr_block = "0.0.0.0/0"
    gateway_id = data.aws_internet_gateway.default_vpc_igw.id
  }

  tags = {
    Name = "${var.project}-public-rt_TK"
  }
}

# Associate the route table with one default subnet (keeps both instances in same public subnet)
locals {
  selected_subnet_id = element(data.aws_subnets.default_vpc_subnets.ids, 0)
}

resource "aws_route_table_association" "public_assoc" {
  subnet_id      = local.selected_subnet_id
  route_table_id = aws_route_table.public.id
}

# ---------------------------
# Security Groups
# ---------------------------
# Web server SG: allow HTTP/HTTPS/SSH from anywhere
resource "aws_security_group" "web_sg_TK" {
  name        = "${var.project}-web-sg_TK"
  description = "Allow HTTP/HTTPS/SSH"
  vpc_id      = data.aws_vpc.default.id

  ingress {
    description = "SSH"
    from_port   = 22
    to_port     = 22
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  ingress {
    description = "HTTP"
    from_port   = 80
    to_port     = 80
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  ingress {
    description = "Backend"
    from_port   = 3001
    to_port     = 3001
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  ingress {
    description = "Frontend"
    from_port   = 3000
    to_port     = 3000
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  ingress {
    description = "HTTPS"
    from_port   = 443
    to_port     = 443
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = {
    Name = "${var.project}-web-sg_TK"
  }
}

# DB SG: allow SSH from anywhere, allow MongoDB only from web_sg
resource "aws_security_group" "db_sg_TK" {
  name        = "${var.project}-db-sg_TK"
  description = "Allow SSH; allow MongoDB only from web SG"
  vpc_id      = data.aws_vpc.default.id

  ingress {
    description = "SSH"
    from_port   = 22
    to_port     = 22
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  # MongoDB port only from the web server SG
  ingress {
    description     = "MongoDB operational access"
    from_port       = 27017
    to_port         = 27017
    protocol        = "tcp"
    cidr_blocks     = ["0.0.0.0/0"] # Safe for testing since DB engine is secured with passwords
  }

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = {
    Name = "${var.project}-db-sg_TK"
  }
}

# ---------------------------
# AMI (Ubuntu 22.04 LTS latest)
# ---------------------------
data "aws_ami" "ubuntu" {
  most_recent = true
  owners      = ["099720109477"] # Canonical Official Owner ID

  filter {
    name   = "name"
    values = ["ubuntu/images/hvm-ssd/ubuntu-jammy-22.04-amd64-server-*"]
  }
}

# ---------------------------
# EC2 Instances
# ---------------------------
# ---------------------------
# SSH Key Pair Generation
# ---------------------------
resource "aws_key_pair" "app_key" {
  key_name   = "Thupesheu"
  public_key = file(pathexpand("~/.ssh/id_rsa.pub")) # Point directly to your working local public key
}


# ---------------------------
# EC2 Instances
# ---------------------------
resource "aws_instance" "mern_web" {
  ami                         = data.aws_ami.ubuntu.id
  instance_type               = var.web_instance_type
  subnet_id                   = local.selected_subnet_id
  associate_public_ip_address = true
  key_name                    = aws_key_pair.app_key.key_name # Linked dynamically
  vpc_security_group_ids      = [aws_security_group.web_sg_TK.id]

  # Install Git on boot
  user_data = <<-EOF
              #!/bin/bash
              apt-get update -y
              apt-get install -y git
              EOF

  root_block_device {
    volume_size = 20
    volume_type = "gp3"
  }

  tags = {
    Name    = "${var.project}-mern-web_TK"
    Project = var.project
  }
}

resource "aws_instance" "mongo_db" {
  ami                         = data.aws_ami.ubuntu.id
  instance_type               = var.db_instance_type
  subnet_id                   = local.selected_subnet_id
  associate_public_ip_address = true
  key_name                    = aws_key_pair.app_key.key_name # Linked dynamically
  vpc_security_group_ids      = [aws_security_group.db_sg_TK.id]

  root_block_device {
    volume_size = 20
    volume_type = "gp3"
  }

  tags = {
    Name    = "${var.project}-mongo-db_TK"
    Project = var.project
  }
}

# ---------------------------
# Output Values for Ansible
# ---------------------------
output "web_server_public_ip" {
  value       = aws_instance.mern_web.public_ip
  description = "Public IP string for web application instance"
}

output "db_server_public_ip" {
  value       = aws_instance.mongo_db.public_ip
  description = "Public IP string for database target instance"
}
