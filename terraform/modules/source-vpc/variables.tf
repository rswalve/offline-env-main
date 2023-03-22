variable "project_name" {
  nullable = false
  type = string
  description = "The project name - will be used in the names of all resources."
}

variable "vpc_cidr_block" {
  nullable = false
  type = string
  description = "This is the CIDR block for the VPC"
}

variable "public_subnet_cidr_block" {
  nullable = false
  type = string
  description = "This is the CIDR block for the public subnet"
}

variable "mgmt_server_ami_id" {
  nullable = false
  type = string
  description = "AMI to be used for jumpbox"
}

variable "instance_keypair_name" {
  nullable = false
  type = string
  description = "The name of the keypair to be used for the mgmt server ec2 instance"
}

variable "remote_access_cidr_block" {
  description = "The IP address of the (remote) server that is allowed to access the nodes (as a /32 CIDR block)"
}

variable "peering_connection_id" {
  nullable = false
  type = string
  description = "The id of the peering connection for connecting to peer vpc"
}

variable "peer_vpc_cidr_block" {
  nullable = false
  type = string
  description = "This is the CIDR block for the peer VPC"
}

