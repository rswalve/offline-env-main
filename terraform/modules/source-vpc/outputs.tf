output "mgmt_server_public_ip" {
  value = aws_instance.mgmt_server.public_ip
}

output "vpc_id" {
  value = aws_vpc.this.id
}
