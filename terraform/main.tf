terraform {
  required_version = ">= 1.5.0"
  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 5.0"
    }
    local = {
      source  = "hashicorp/local"
      version = "~> 2.4"
    }
  }
}

provider "aws" {
  region = var.aws_region
}

# 1. AWS VPC
resource "aws_vpc" "main" {
  cidr_block           = "10.0.0.0/16"
  enable_dns_hostnames = true
  enable_dns_support   = true

  tags = {
    Name    = "nexus-vpc"
    Project = "nexus-platform"
  }
}

# 2. Internet Gateway (IGW)
resource "aws_internet_gateway" "gw" {
  vpc_id = aws_vpc.main.id

  tags = {
    Name    = "nexus-igw"
    Project = "nexus-platform"
  }
}

# 3. Public Subnet
resource "aws_subnet" "public" {
  vpc_id                  = aws_vpc.main.id
  cidr_block              = "10.0.1.0/24"
  availability_zone       = "${var.aws_region}a"
  map_public_ip_on_launch = true

  tags = {
    Name                     = "nexus-public-subnet"
    Project                  = "nexus-platform"
    "kubernetes.io/role/elb" = "1"
  }
}

# 4. Route Table & Association
resource "aws_route_table" "public_rt" {
  vpc_id = aws_vpc.main.id

  route {
    cidr_block = "0.0.0.0/0"
    gateway_id = aws_internet_gateway.gw.id
  }

  tags = {
    Name    = "nexus-public-rt"
    Project = "nexus-platform"
  }
}

resource "aws_route_table_association" "public_assoc" {
  subnet_id      = aws_subnet.public.id
  route_table_id = aws_route_table.public_rt.id
}

# 5. Security Group (nexus-k3s-sg)
resource "aws_security_group" "node_sg" {
  name        = "nexus-k3s-sg"
  description = "Strict traffic filtering for the Nexus K3s node"
  vpc_id      = aws_vpc.main.id

  ingress {
    description = "SSH Console Management"
    from_port   = 22
    to_port     = 22
    protocol    = "tcp"
    cidr_blocks = [var.admin_ip]
  }

  ingress {
    description = "Public HTTP Ingress"
    from_port   = 80
    to_port     = 80
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  ingress {
    description = "Public HTTPS Ingress"
    from_port   = 443
    to_port     = 443
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  ingress {
    description = "K3s API Server Access"
    from_port   = 6443
    to_port     = 6443
    protocol    = "tcp"
    cidr_blocks = [var.admin_ip]
  }

  egress {
    description = "All outbound traffic"
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = {
    Name    = "nexus-k3s-sg"
    Project = "nexus-platform"
  }
}

# 6. SSH Key Pair
resource "aws_key_pair" "auth" {
  key_name   = "nexus-deploy-key"
  public_key = file(pathexpand(var.ssh_public_key_path))
}

# 7. Automatic AMI search for Ubuntu 24.04 LTS Minimal
data "aws_ami" "ubuntu_minimal" {
  most_recent = true
  owners      = ["099720109477"]

  filter {
    name   = "name"
    values = ["ubuntu-minimal/images/hvm-ssd-gp3/ubuntu-noble-24.04-amd64-minimal-*"]
  }

  filter {
    name   = "virtualization-type"
    values = ["hvm"]
  }
}

# 8. EC2 Instance
resource "aws_instance" "k3s_node" {
  ami                    = data.aws_ami.ubuntu_minimal.id
  instance_type          = "t3.small"
  subnet_id              = aws_subnet.public.id
  vpc_security_group_ids = [aws_security_group.node_sg.id]
  key_name               = aws_key_pair.auth.key_name

  root_block_device {
    volume_size           = 30
    volume_type           = "gp3"
    encrypted             = true
    delete_on_termination = true
    tags = {
      Name = "nexus-k3s-root-disk"
    }
  }

  tags = {
    Name        = "nexus-k3s-node"
    Environment = "dev"
    Project     = "nexus-platform"
  }
}

# 9. Automatic export to inventory.ini
resource "local_file" "ansible_inventory" {
  content = <<-EOT
    [k3s_nodes]
    nexus-k3s-master ansible_host=${aws_instance.k3s_node.public_ip} ansible_user=ubuntu ansible_ssh_private_key_file=${pathexpand(var.ssh_private_key_path)}
  EOT
  filename        = "${path.module}/../ansible/inventory.ini"
  file_permission = "0644"
}
