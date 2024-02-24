variable "aws_access_key" {}
variable "aws_secret_key" {}
variable "availability_zones" {
  default = ["ap-southeast-1a", "ap-southeast-1b"]  
}

variable "public_subnet_cidr_blocks" {
  default = ["10.10.1.0/24", "10.10.2.0/24"] 
}

variable "private_subnet_cidr_blocks" {
  default = ["10.10.3.0/24", "10.10.4.0/24"]  
}