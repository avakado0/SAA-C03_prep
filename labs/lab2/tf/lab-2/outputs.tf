output "vpc_id" {
  description = "ID of the Lab 2 VPC."
  value       = aws_vpc.lab.id
}

output "public_subnet_id" {
  description = "ID of the public subnet."
  value       = aws_subnet.public.id
}

output "route_table_id" {
  description = "ID of the public route table."
  value       = aws_route_table.public.id
}

output "internet_gateway_id" {
  description = "ID of the Internet Gateway."
  value       = aws_internet_gateway.lab.id
}

output "security_group_id" {
  description = "ID of the EC2 Security Group."
  value       = aws_security_group.web.id
}

output "instance_id" {
  description = "ID of the Lab 2 EC2 instance."
  value       = aws_instance.web.id
}

output "private_ip" {
  description = "Private IPv4 address of the EC2 instance."
  value       = aws_instance.web.private_ip
}

output "public_ip" {
  description = "Public IPv4 address of the EC2 instance."
  value       = aws_instance.web.public_ip
}

output "fastapi_url" {
  description = "URL used to test the FastAPI application."
  value       = "http://${aws_instance.web.public_ip}"
}

output "ssh_command" {
  description = "SSH command template when an existing key pair was supplied."
  value       = var.key_name != null ? "ssh -i ~/.ssh/<your-key>.pem ec2-user@${aws_instance.web.public_ip}" : "No key_name supplied."
}
