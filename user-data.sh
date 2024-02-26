#!/bin/bash
sudo su
yum update -y
yum install -y openswan

cutomer_public_ip = aws_instance.ec2_customer.public_ip
tunnel1_ip = aws_vpn_connection.vpn_connection.tunnel1_address
tunnel1_preshared_key = aws_vpn_connection.vpn_connection.tunnel1_preshared_key
tunnel2_ip = aws_vpn_connection.vpn_connection.tunnel2_address
tunnel2_preshared_key = aws_vpn_connection.vpn_connection.tunnel2_preshared_key

cat <<EOF > /etc/sysctl.conf
net.ipv4.ip_forward = 1
net.ipv4.conf.all.accept_redirects = 0
net.ipv4.conf.all.send_redirects = 0
EOF

sysctl -p

cat <<EOF > /etc/ipsec.d/aws.conf
conn Tunnel1
	authby=secret
	auto=start
	left=%defaultroute
	leftid=${cutomer_public_ip}
	right=${tunnel1_ip}
	type=tunnel
	ikelifetime=8h
	keylife=1h
	phase2alg=aes128-sha1;modp1024
	ike=aes128-sha1;modp1024
	keyingtries=%forever
	keyexchange=ike
	leftsubnet=10.11.0.0/16
	rightsubnet=10.10.0.0/16
	dpddelay=10
	dpdtimeout=30
	dpdaction=restart_by_peer
	overlapip=yes

conn Tunnel2
	authby=secret
	auto=start
	left=%defaultroute
	leftid=${cutomer_public_ip}
	right=${tunnel2_ip}
	type=tunnel
	ikelifetime=8h
	keylife=1h
	phase2alg=aes128-sha1;modp1024
	ike=aes128-sha1;modp1024
	keyingtries=%forever
	keyexchange=ike
	leftsubnet=10.11.0.0/16
	rightsubnet=10.10.0.0/16
	dpddelay=10
	dpdtimeout=30
	dpdaction=restart_by_peer
	overlapip=yes
EOF



cat <<EOF > /etc/ipsec.d/aws.secrets
${customer_public_ip} ${tunnel1_ip}: PSK ${tunnel1_preshared_key}
${customer_public_ip} ${tunnel2_ip}: PSK ${tunnel2_preshared_key}
EOF



service network restart 
chkconfig ipsec on
service ipsec start
service ipsec status