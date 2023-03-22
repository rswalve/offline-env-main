# module vpc

# Setup our source VPC.  Basically a vpc containing a single magament server that will be used
# to install a k8s cluster in a target peer vpc.  This VPC only allows external connectivity
# from a single remote host to our management server.  There is no connectivity with the internet,
# so we have to setup VPC endpoints for the various AWS services that the installation process
# will need

terraform {
  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 4.0"
    }
  }
}

locals {
  resource_name_prefix = "${var.project_name}-src"
}

resource "aws_vpc" "this" {
  cidr_block = var.vpc_cidr_block
  enable_dns_support = true
  enable_dns_hostnames = true
  tags = {
    Name = "${local.resource_name_prefix}"
  }
}

resource "aws_internet_gateway" "this" {
  vpc_id = aws_vpc.this.id
  tags = {
    Name = "${local.resource_name_prefix}"
  }
}

resource "aws_subnet" "public" {
  vpc_id = aws_vpc.this.id
  cidr_block = var.public_subnet_cidr_block
  tags = {
    Name = "${local.resource_name_prefix}-public"
  }
  # Establish a way for external modules to depend on the igw
  # without having to expose the igw as an output
  depends_on = [aws_internet_gateway.this]
}

resource "aws_route_table" "public" {
  vpc_id = aws_vpc.this.id

  tags = {
    Name = "${local.resource_name_prefix}-public"
  }
}

resource "aws_route" "public-external" {
  route_table_id         = aws_route_table.public.id
  destination_cidr_block = var.remote_access_cidr_block
  gateway_id = aws_internet_gateway.this.id
}

resource "aws_route" "public-peer-vpc" {
  route_table_id         = aws_route_table.public.id
  destination_cidr_block = var.peer_vpc_cidr_block
  vpc_peering_connection_id = var.peering_connection_id
}

resource "aws_route_table_association" "public" {
  subnet_id      = aws_subnet.public.id
  route_table_id = aws_route_table.public.id
}

resource "aws_security_group" "remote-access" {
  name        = "${local.resource_name_prefix}-remote"
  description = "Allow remote access to mgmt server"
  vpc_id      = aws_vpc.this.id

  ingress {
    description      = "ssh from remote server"
    protocol         = "tcp"
    from_port        = "22"
    to_port          = "22"
    cidr_blocks      = [var.remote_access_cidr_block]
  }
  ingress {
    description      = "internal https from remote server"
    protocol         = "tcp"
    from_port        = "6443"
    to_port          = "6443"
    cidr_blocks      = [var.remote_access_cidr_block]
  }
  ingress {
    description      = "https from remote server"
    protocol         = "tcp"
    from_port        = "443"
    to_port          = "443"
    cidr_blocks      = [var.remote_access_cidr_block]
  }
  ingress {
    description      = "icmp from remote server"
    protocol         = "icmp"
    from_port        = "-1"
    to_port          = "-1"
    cidr_blocks      = [var.remote_access_cidr_block]
  }
  # AWS normally provides a default egress rule, but terraform
  # deletes it by default, so we need to add it here to keep it
  egress {
    from_port        = 0
    to_port          = 0
    protocol         = "-1"
    cidr_blocks      = ["0.0.0.0/0"]
    ipv6_cidr_blocks = ["::/0"]
  }


  tags = {
    Name = "${local.resource_name_prefix}-remote"
  }
}

resource "aws_instance" "mgmt_server" {
  ami           = var.mgmt_server_ami_id
  associate_public_ip_address = true
  ebs_block_device {
    device_name = "/dev/sda1"
    volume_size = "50"
    tags = {
      Name = "${local.resource_name_prefix}-mgmt_server"
      Environment = var.project_name
    }
  }
  instance_type = "t3.micro"
  key_name = var.instance_keypair_name
  private_ip =  cidrhost(var.public_subnet_cidr_block,10)
  source_dest_check = false
  subnet_id = aws_subnet.public.id
  vpc_security_group_ids = [aws_security_group.remote-access.id]

  tags = {
    Name = "${local.resource_name_prefix}-mgmt_server"
  }
}

resource "aws_security_group" "vpce" {
  name        = "${local.resource_name_prefix}-vpce"
  description = "allow access to vpc interface endpoints"
  vpc_id      = aws_vpc.this.id

  ingress {
    description      = "https from subnet"
    protocol         = "tcp"
    from_port        = "443"
    to_port          = "443"
    cidr_blocks      = [var.public_subnet_cidr_block]
  }
  # AWS normally provides a default egress rule, but terraform
  # deletes it by default, so we need to add it here to keep it
  egress {
    from_port        = 0
    to_port          = 0
    protocol         = "-1"
    cidr_blocks      = ["0.0.0.0/0"]
    ipv6_cidr_blocks = ["::/0"]
  }


  tags = {
    Name = "${local.resource_name_prefix}-vpce"
  }
}

resource "aws_vpc_endpoint" "s3" {
  vpc_id       = aws_vpc.this.id
  service_name = "com.amazonaws.us-gov-west-1.s3"
  route_table_ids = [aws_route_table.public.id]
  tags = {
    Name = "${local.resource_name_prefix}-s3"
  }
}

resource "aws_vpc_endpoint" "ec2" {
  vpc_id            = aws_vpc.this.id
  service_name = "com.amazonaws.us-gov-west-1.ec2"
  vpc_endpoint_type = "Interface"

  security_group_ids = [
    aws_security_group.vpce.id
  ]
  subnet_ids = [
    aws_subnet.public.id
  ]
  private_dns_enabled = true
  tags = {
    Name = "${local.resource_name_prefix}-ec2"
  }
}

resource "aws_vpc_endpoint" "elb" {
  vpc_id            = aws_vpc.this.id
  service_name = "com.amazonaws.us-gov-west-1.elasticloadbalancing"
  vpc_endpoint_type = "Interface"

  security_group_ids = [
    aws_security_group.vpce.id
  ]
  subnet_ids = [
    aws_subnet.public.id
  ]
  private_dns_enabled = true
  tags = {
    Name = "${local.resource_name_prefix}-elb"
  }
}

resource "aws_vpc_endpoint" "sts" {
  vpc_id            = aws_vpc.this.id
  service_name = "com.amazonaws.us-gov-west-1.sts"
  vpc_endpoint_type = "Interface"

  security_group_ids = [
    aws_security_group.vpce.id
  ]
  subnet_ids = [
    aws_subnet.public.id
  ]
  private_dns_enabled = true
  tags = {
    Name = "${local.resource_name_prefix}-sts"
  }
}



