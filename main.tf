provider "aws" {
  region = "ap-southeast-1"
  access_key = var.aws_access_key
  secret_key = var.aws_secret_key
}

//1. create VPC
resource "aws_vpc" "vpc" {
  cidr_block       = "10.10.0.0/16"
  tags = {
    Name = "VPC HCM"
  }
}

//2. create internet gateway
resource "aws_internet_gateway" "igw" {
  vpc_id = aws_vpc.vpc.id
  tags = {
    Name = "IGW"
  }
}

//3. create 4 Subnets in ap-southeast-1a,1b
resource "aws_subnet" "public_subnet" {
  count      = length(var.public_subnet_cidr_blocks)
  vpc_id     = aws_vpc.vpc.id
  cidr_block = var.public_subnet_cidr_blocks[count.index]
  availability_zone = var.availability_zones[count.index % length(var.availability_zones)]
  
  tags = {
    Name = "Public Subnet ${count.index + 1}"
  }
}
resource "aws_subnet" "private_subnet" {
  count      = length(var.private_subnet_cidr_blocks)
  vpc_id     = aws_vpc.vpc.id
  cidr_block = var.private_subnet_cidr_blocks[count.index]
  availability_zone = var.availability_zones[count.index % length(var.availability_zones)]
  
  tags = {
    Name = "Private Subnet ${count.index + 1}"
  }
}

//4. create EIP to network interface
resource "aws_eip" "eip" {
  domain                    = "vpc"
  # network_interface         = aws_network_interface.eni.id
  # associate_with_private_ip = "10.10.1.50"
  depends_on                = [aws_internet_gateway.igw]
}

//5. create NAT Gateway
resource "aws_nat_gateway" "nat_gateway" {
  allocation_id = aws_eip.eip.id
  subnet_id     = aws_subnet.public_subnet[1].id //create nat gw in public subnet 2

  tags = {
    Name = "NGW"
  }
  depends_on = [aws_internet_gateway.igw]
}

//6. create route table
resource "aws_route_table" "public_route_table" {
  vpc_id = aws_vpc.vpc.id
  route {
    cidr_block = "0.0.0.0/0"
    gateway_id = aws_internet_gateway.igw.id
  }

  tags = {
    Name = "Public route table"
  }
}
resource "aws_route_table" "private_route_table" {
  vpc_id = aws_vpc.vpc.id
  route {
    cidr_block = "0.0.0.0/0"
    nat_gateway_id = aws_nat_gateway.nat_gateway.id
  }

  tags = {
    Name = "Public route table"
  }
}

//7. associate public subnet with public route table
resource "aws_route_table_association" "public_associate" {
  count = length(aws_subnet.public_subnet)
  subnet_id      = aws_subnet.public_subnet[count.index].id
  route_table_id = aws_route_table.public_route_table.id
}
resource "aws_route_table_association" "private_associate" {
  count = length(aws_subnet.private_subnet)
  subnet_id      = aws_subnet.private_subnet[count.index].id
  route_table_id = aws_route_table.private_route_table.id
}

//8. create Security Group allow ssh, imcp
resource "aws_security_group" "public_sg" {
  name        = "public_sg"
  description = "Allow 22, ICMP inbound traffic and all outbound traffic"
  vpc_id      = aws_vpc.vpc.id

  tags = {
    Name = "public_sg"
  }
  ingress = [{
    description = "SSH",
    from_port = 22,
    to_port = 22,
    protocol = "tcp",
    cidr_blocks = ["0.0.0.0/0"]
    ipv6_cidr_blocks = ["::/0"]
    prefix_list_ids = []
    security_groups = []
    self = false
  },{
    description = "ICMP",
    from_port = -1,
    to_port = -1,
    protocol = "icmp",
    cidr_blocks = ["0.0.0.0/0"]
    ipv6_cidr_blocks = ["::/0"]
    prefix_list_ids = []
    security_groups = []
    self = false
  }]

  egress = [{
    description = "all trafic",
    from_port = 0,
    to_port = 0,
    protocol = "-1",
    cidr_blocks = ["0.0.0.0/0"]
    ipv6_cidr_blocks = ["::/0"]
    prefix_list_ids = []
    security_groups = []
    self = false
  }]
}

resource "aws_security_group" "private_sg" {
  name        = "private_sg"
  description = "Allow 22, ICMP from PUBLIC SUBNET inbound traffic and all outbound traffic"
  vpc_id      = aws_vpc.vpc.id

  tags = {
    Name = "private_sg"
  }
  ingress = [{
    description = "SSH",
    from_port = 22,
    to_port = 22,
    protocol = "tcp",
    cidr_blocks = var.public_subnet_cidr_blocks
    ipv6_cidr_blocks = ["::/0"]
    prefix_list_ids = []
    security_groups = []
    self = false
  },{
    description = "ICMP",
    from_port = -1,
    to_port = -1,
    protocol = "icmp",
    cidr_blocks = var.public_subnet_cidr_blocks
    ipv6_cidr_blocks = ["::/0"]
    prefix_list_ids = []
    security_groups = []
    self = false
  }]

  egress = [{
    description = "all trafic",
    from_port = 0,
    to_port = 0,
    protocol = "-1",
    cidr_blocks = ["0.0.0.0/0"]
    ipv6_cidr_blocks = ["::/0"]
    prefix_list_ids = []
    security_groups = []
    self = false
  }]
}

//9. create 2 EC2 public and private subnet
resource "aws_instance" "public_ec2" {
  ami = "ami-07a6e3b1c102cdba8"
  instance_type = "t2.micro"
  key_name = "vpc-keypair"
  subnet_id = aws_subnet.public_subnet[0].id
  security_groups = [aws_security_group.public_sg.id]
  associate_public_ip_address = true  # Ensure instance gets a public IP
  tags = {
    Name: "EC2_Public"        
  }


}
resource "aws_instance" "private_ec2" {
  ami = "ami-07a6e3b1c102cdba8"
  instance_type = "t2.micro"
  key_name = "vpc-keypair"
  subnet_id = aws_subnet.private_subnet[0].id
  security_groups = [aws_security_group.private_sg.id]
  tags = {
    Name: "EC2_Private"        
  }
}