variable "cidr_block" {
  default     = "10.0.0.0/8"
  type        = string
  description = "CIDR block for the VPC"
}

variable "public_subnet_cidr_blocks" {
  default     = ["10.0.1.0/24", "10.0.2.0/24"]
  type        = list(any)
  description = "List of public subnet CIDR blocks"
}

variable "private_subnet_cidr_blocks" {
  default     = ["10.0.101.0/24", "10.0.102.0/24"]
  type        = list(any)
  description = "List of private subnet CIDR blocks"
}

variable "allowed_ips" {
  type        = list(any)
  description = "List of allowed IP addresses to connect to the SSH service. This should be list of Boundary workers outbound addresses"
}


variable "availability_zones" {
  default     = ["us-west-2a", "us-west-2b"]
  type        = list(any)
  description = "List of availability zones"
}
variable "aws_region" {
  default = "us-west-2"
  type    = string
}
variable "aws_profile" {
  type    = string
}

variable "worker_count" {
  type = number
  description = "Number of Boundary target to spin up"
}