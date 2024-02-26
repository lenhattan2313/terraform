//1. create vpc to simulate on premises
resource "aws_vpc" "vpc_customer" {
  cidr_block       = "10.11.0.0/16"
  tags = {
    Name = "VPC Customer"
  } 
}

//2. create internet gateway
resource "aws_internet_gateway" "igw_customer" {
  vpc_id = aws_vpc.vpc_customer.id
  tags = {
    Name = "IGW Cutomer"
  }
}

//3. create subnet in ap-southeast-2a
resource "aws_subnet" "subnet_customer" {
  vpc_id     = aws_vpc.vpc_customer.id
  cidr_block = "10.11.1.0/24"
  availability_zone = "ap-southeast-1c"
  
  tags = {
    Name = "Subnet Customer"
  }
}

//4. create route table
resource "aws_route_table" "rt_customer" {
  vpc_id = aws_vpc.vpc_customer.id
  route {
    cidr_block = "0.0.0.0/0"
    gateway_id = aws_internet_gateway.igw_customer.id
  }

  tags = {
    Name = "Route Table Cutomer"
  }
}

//5. associate subnet with route table
resource "aws_route_table_association" "customer_rt_associate" {
  subnet_id      = aws_subnet.subnet_customer.id
  route_table_id = aws_route_table.rt_customer.id
}

//6. create security groups allow ssh, imcp, ipsec
resource "aws_security_group" "sg_customer" {
  name        = "sg_customer"
  description = "Allow 22, ICMP, IPSEC inbound traffic and all outbound traffic"
  vpc_id      = aws_vpc.vpc_customer.id

  tags = {
    Name = "SG Customer"
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
  },{
    description = "IPSEC1",
    from_port = 400,
    to_port = 400,
    protocol = "udp",
    cidr_blocks = ["0.0.0.0/0"]
    ipv6_cidr_blocks = ["::/0"]
    prefix_list_ids = []
    security_groups = []
    self = false
  },{
    description = "IPSEC2",
    from_port = 500,
    to_port = 500,
    protocol = "tcp",
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


# //create file shell handle config vpn
# data "template_file" "init" {
#   filename = file("user-data.sh")
#   vars = {
#     cutomer_public_ip = aws_instance.ec2_customer.public_ip,
#     tunnel1_ip = aws_vpn_connection.vpn_connection.tunnel1_address,
#     tunnel1_preshared_key = aws_vpn_connection.vpn_connection.tunnel1_preshared_key,
#     tunnel2_ip = aws_vpn_connection.vpn_connection.tunnel2_address,
#     tunnel2_preshared_key = aws_vpn_connection.vpn_connection.tunnel2_preshared_key,

#   }
# }


//7. create EC2 
resource "aws_instance" "ec2_customer" {
  ami = "ami-0eb4694aa6f249c52"
  instance_type = "t2.micro"
  key_name = "vpc-keypair"
  subnet_id = aws_subnet.subnet_customer.id
  security_groups = [aws_security_group.sg_customer.id]
  associate_public_ip_address = true  # Ensure instance gets a public IP
  tags = {
    Name: "EC2 Customer"        
  }
  user_data = file("user-data.sh") //handle config vpn
  # VPN instance configuration 
  # provisioner "remote-exec" {
  #   script = "user-data.sh"
  #   connection {
  #     type        = "ssh"
  #     user        = "ec2-user"           # Update with the SSH user for your instance
  #     private_key = file("~/Code/vpc-keypair.pem")  # Update with the path to your SSH private key
  #     host        = self.public_ip      # Use self to reference the instance's public IP
  #   }
  # }

}
output "cutomer_public_ip" {
  value = aws_instance.ec2_customer.public_ip
}

//8. create customer gateway
resource "aws_customer_gateway" "cutomer_gw" {
  bgp_asn    = 65000
  ip_address = aws_instance.ec2_customer.public_ip
  type       = "ipsec.1"

  tags = {
    Name = "On-Premise Customer Gateway"
  }
}

//9. create vpn gateway, attach to vpc and route propagation
resource "aws_vpn_gateway" "vpn_gw" {
  vpc_id = aws_vpc.vpc.id

  tags = {
    Name = "VPN gateway"
  }
}

resource "aws_vpn_gateway_attachment" "vpn_attachment" {
  vpc_id         = aws_vpc.vpc.id
  vpn_gateway_id = aws_vpn_gateway.vpn_gw.id
}

resource "aws_vpn_gateway_route_propagation" "vpn_route_public_propagation" {
  vpn_gateway_id = aws_vpn_gateway.vpn_gw.id
  route_table_id = aws_route_table.public_route_table.id
}

resource "aws_vpn_gateway_route_propagation" "vpn_route_private_propagation" {
  vpn_gateway_id = aws_vpn_gateway.vpn_gw.id
  route_table_id = aws_route_table.private_route_table.id
}

//10. create vpn connection
resource "aws_vpn_connection" "vpn_connection" {
  vpn_gateway_id      = aws_vpn_gateway.vpn_gw.id
  customer_gateway_id = aws_customer_gateway.cutomer_gw.id
  type                = "ipsec.1"
  static_routes_only  = true
}

//11. create static route to the on-premise network
resource "aws_vpn_connection_route" "onpremNetwork" {
  destination_cidr_block = "10.11.0.0/16"
  vpn_connection_id      = aws_vpn_connection.vpn_connection.id
}

#output of Tunnel 1 IP address
output "AWStunnel1IP" {
  value = aws_vpn_connection.vpn_connection.tunnel1_address
}

#output of Tunnel 2 IP address
output "AWStunnel2IP" {
  value = aws_vpn_connection.vpn_connection.tunnel2_address
}