# module vpc

# Sets up the target cluster to match what we expect to see on site.
# Expect that we'll need to update this as we find out more 
# about the on-site environment.
#
# For now, all we need is to setup the vpc so that the peering 
# connection can be established. Cluster installation should take
# care of provisioning everything else in the target vpc
#

terraform {
  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 4.0"
    }
  }
}

resource "aws_vpc" "main" {
  cidr_block = var.vpc_cidr_block
  enable_dns_support = true
  enable_dns_hostnames = true
  tags = {
    Name = "${var.project_name}"
  }
}


#
# Most of the stuff below here is really just temporary to allow
# us to test connectivity between the two VPCs.  The cluster
# installation terraform should be provisioning all fo this
# stuff according to its needs
#

resource "aws_subnet" "public" {
  vpc_id = aws_vpc.main.id
  cidr_block = var.public_subnet_cidr_block
  tags = {
    Name = "${var.project_name}-public"
  }
}

resource "aws_route_table" "public" {
  vpc_id = aws_vpc.main.id

  tags = {
    Name = "${var.project_name}-public"
  }
}

resource "aws_route" "public-vpc-peer" {
  route_table_id         = aws_route_table.public.id
  destination_cidr_block = var.peer_vpc_cidr_block
  vpc_peering_connection_id = var.peering_connection_id
}

resource "aws_route_table_association" "public" {
  subnet_id      = aws_subnet.public.id
  route_table_id = aws_route_table.public.id
}

resource "aws_security_group" "main" {
  name        = "${var.project_name}-remote"
  description = "Allow remote access to cluster"
  vpc_id      = aws_vpc.main.id

  ingress {
    description      = "ssh from mgmt server"
    protocol         = "tcp"
    from_port        = "22"
    to_port          = "22"
    cidr_blocks      = [var.peer_vpc_cidr_block]
  }
  ingress {
    description      = "internal https from mgmt server"
    protocol         = "tcp"
    from_port        = "6443"
    to_port          = "6443"
    cidr_blocks      = [var.peer_vpc_cidr_block]
  }
  ingress {
    description      = "https from mgmt server"
    protocol         = "tcp"
    from_port        = "443"
    to_port          = "443"
    cidr_blocks      = [var.peer_vpc_cidr_block]
  }
  ingress {
    description      = "icmp from mgmt server"
    protocol         = "icmp"
    from_port        = "-1"
    to_port          = "-1"
    cidr_blocks      = [var.peer_vpc_cidr_block]
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
    Name = "${var.project_name}-remote"
  }
}

# This is temporary just so we can check connectivity between the
# two vpcs.  We'll probably make this optional with variable
resource "aws_instance" "testbox" {
  ami           = var.testbox_ami_id
  associate_public_ip_address = false
  ebs_block_device {
    device_name = "/dev/sda1"
    volume_size = "50"
    tags = {
      Name = "${var.project_name}-testbox"
      Environment = var.project_name
    }
  }
  instance_type = "t3.micro"
  key_name = var.instance_keypair_name
  private_ip =  cidrhost(var.public_subnet_cidr_block,10)
  source_dest_check = false
  subnet_id = aws_subnet.public.id
  vpc_security_group_ids = [aws_security_group.main.id]

  tags = {
    Name = "${var.project_name}-testbox"
  }
}

