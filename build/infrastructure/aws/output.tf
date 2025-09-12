output "host_dns" {
  value = aws_instance.host.public_dns
}

output "private_key_pem" {
  value = tls_private_key.ssh_key.private_key_pem
  sensitive = true
}
