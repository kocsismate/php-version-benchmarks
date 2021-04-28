output "host_dns" {
  value = aws_instance.host.public_dns
}

output "client_dns" {
  value = aws_instance.client.public_dns
}
