variable "aws_region" {
  description = "AWS region in which the Lab 2 infrastructure will be created."
  type        = string
  default     = "eu-north-1"
}

variable "project_name" {
  description = "Name prefix used for all Lab 2 resources."
  type        = string
  default     = "saa-lab-2"
}

variable "ssh_allowed_cidr" {
  description = "IPv4 CIDR allowed to SSH to the EC2 instance. Use your current public IPv4 address with /32."
  type        = string
}

variable "vpc_cidr" {
  description = "IPv4 CIDR block for the Lab 2 VPC."
  type        = string
  default     = "10.20.0.0/16"
}

variable "public_subnet_cidr" {
  description = "IPv4 CIDR block for the public subnet."
  type        = string
  default     = "10.20.1.0/24"
}

variable "availability_zone" {
  description = "Availability Zone for the public subnet. Leave null to use the first available AZ."
  type        = string
  default     = null
}

variable "instance_type" {
  description = "EC2 instance type used for the lab."
  type        = string
  default     = "t3.micro"
}

variable "key_name" {
  description = "Optional existing EC2 key pair name for SSH access."
  type        = string
  default     = null
}
