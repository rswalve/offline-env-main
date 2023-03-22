output "mgmt_server_public_ip" {
  value = module.source-vpc.mgmt_server_public_ip
}

output "ssh_private_key" {
  value = tls_private_key.ssh_key.private_key_pem
  sensitive = true
}

