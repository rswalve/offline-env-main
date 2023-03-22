
#
# Creates our source and target VPCs and sets up a peering connection between them
#

terraform {
  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 4.0"
    }
  }
}

provider "aws" {
  profile = var.aws_profile_name
  region = var.aws_region
  default_tags {
    tags = {
      Environment = var.project_name
    }
  }  
}

provider "tls" {
  
}

variable "project_name" {
  nullable = false
  description = "The project name - will be used in the names of all resources."
}

variable "aws_profile_name" {
  nullable = false
  description = "That name of the aws profile to be use when access AWS APIs"
}

variable "aws_region" {
  # per https://github.com/hashicorp/terraform-provider-aws/issues/7750 the aws provider is not
  # using the region defined in aws profile, so it will need to be specified
  nullable = false
  description = "The region to operate in"
}

variable "remote_access_address" {
  description = "The IP address of the (remote) server that is allowed to access the source vpc (as a /32 CIDR block)"
}

variable "source_vpc_cidr_block" {
  default = "10.4.0.0/16"
  description = "This is the CIDR block for the VPC where the cluster will live"
}

variable "target_vpc_cidr_block" {
  default = "10.2.0.0/16"
  description = "This is the CIDR block for the VPC where the cluster will live"
}



data "aws_caller_identity" "current" {}

data "aws_ami" "centos_terraform" {
  most_recent      = true

  filter {
    name   = "name"
    values = ["centos7-terraform-*"]
  }

  filter {
    name   = "root-device-type"
    values = ["ebs"]
  }

  filter {
    name   = "virtualization-type"
    values = ["hvm"]
  }

  filter {
    name = "architecture"
    values = ["x86_64"]
  }

}

resource "tls_private_key" "ssh_key" {
  algorithm = "RSA"
  rsa_bits  = 4096
}

resource "aws_key_pair" "ec2_keypair" {
  key_name   = var.project_name
  public_key = tls_private_key.ssh_key.public_key_openssh
}

module "source-vpc" {
  source = "./modules/source-vpc"

  project_name = var.project_name
  instance_keypair_name = aws_key_pair.ec2_keypair.key_name
  vpc_cidr_block = var.source_vpc_cidr_block
  peer_vpc_cidr_block = var.target_vpc_cidr_block
  peering_connection_id = aws_vpc_peering_connection.main.id
  public_subnet_cidr_block = cidrsubnet(var.source_vpc_cidr_block,8,1)
  mgmt_server_ami_id = data.aws_ami.centos_terraform.id
  remote_access_cidr_block = var.remote_access_address
}

module "target-vpc" {
  source = "./modules/target-vpc"

  project_name = var.project_name
  instance_keypair_name = aws_key_pair.ec2_keypair.key_name
  vpc_cidr_block = var.target_vpc_cidr_block
  peer_vpc_cidr_block = var.source_vpc_cidr_block
  peering_connection_id = aws_vpc_peering_connection.main.id
  public_subnet_cidr_block = cidrsubnet(var.target_vpc_cidr_block,8,1)
  testbox_ami_id = data.aws_ami.centos_terraform.id
  remote_access_cidr_block = "${module.source-vpc.mgmt_server_public_ip}/32"

}

resource "aws_vpc_peering_connection" "main" {
  peer_owner_id = data.aws_caller_identity.current.account_id
  peer_vpc_id   = module.source-vpc.vpc_id
  vpc_id        = module.target-vpc.vpc_id
  auto_accept   = true

  tags = {
    Name = "${var.project_name}"
  }
}