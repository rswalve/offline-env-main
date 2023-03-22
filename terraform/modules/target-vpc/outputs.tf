output "jumpbox_public_ip" {
  value = aws_instance.testbox.public_ip
}

output "vpc_id" {
  value = aws_vpc.main.id
}
