# resource "aws_instance" "idc-seoul_dns" {
#   provider = aws.seoul
#   ami           = var.seoul-ami
#   instance_type = "t2.micro"
#   associate_public_ip_address = "true"
#   private_ip = "10.2.1.200"
#   subnet_id = aws_subnet.idc-seoul.id
#   security_groups = [aws_security_group.idc-seoul.id]
#   tags = {
#     Name = "idc-seoul_dns"
#   }
#   user_data = <<EOE
# #!/bin/bash
# #!/bin/bash
# hostnamectl --static set-hostname idc-seoul-dns
# sed -i "s/^127.0.0.1 localhost/127.0.0.1 localhost idc-seoul-dns/g" /etc/hosts
# apt-get update -y
# apt-get install bind9 bind9-doc language-pack-ko -y
# cat <<EOT> /etc/bind/named.conf.options
# options {
#   directory "/var/cache/bind";
#   recursion yes;
#   allow-query { any; };
#   forwarders {
#         8.8.8.8;
#         };
#   forward only;
#   auth-nxdomain no;
# };
# zone "awsseoul.internal" {
#     type forward;
#     forward only;
#     forwarders { 10.1.3.250; 10.1.4.250; };
# };
# zone "awssinga.internal" {
#     type forward;
#     forward only;
#     forwarders { 10.3.3.250; 10.3.4.250; };
# };
# EOT
# cat <<EOT> /etc/bind/named.conf.local
# zone "idcseoul.internal" {
#     type master;
#     file "/etc/bind/db.idcseoul.internal";
# };
# zone "2.10.in-addr.arpa" {
#     type master;
#     file "/etc/bind/db.10.2";
# };
# EOT
# cat <<EOT> /etc/bind/db.idcseoul.internal
# \$TTL 30
# @ IN SOA idcseoul.internal. root.idcseoul.internal. (
#   2019122114 ; serial
#   3600       ; refresh
#   900        ; retry
#   604800     ; expire
#   86400      ; minimum ttl
# )
# ; dns server
# @      IN NS ns1.idcseoul.internal.
# ; ip address of dns server
# ns1    IN A  10.2.1.200
# ; Hosts
# db   IN A  10.2.1.100
# dns   IN A  10.2.1.200
# EOT
# cat <<EOT> /etc/bind/db.10.2
# \$TTL 30
# @ IN SOA idcseoul.internal. root.idcseoul.internal. (
#   2019122114 ; serial
#   3600       ; refresh
#   900        ; retry
#   604800     ; expire
#   86400      ; minimum ttl
# )
# ; dns server
# @      IN NS ns1.idcseoul.internal.
# ; ip address of dns server
# 3      IN PTR  ns1.idcseoul.internal.
# ; A Record list
# 100.1    IN PTR  db.idcseoul.internal.
# 200.1    IN PTR  dns.idcseoul.internal.
# EOT
# systemctl start bind9 && systemctl enable bind9
# EOE
# }
######################################################################
# resource "aws_instance" "idc-seoul_db" {
#   provider = aws.seoul
#   ami           = var.seoul-ami
#   instance_type = "t2.micro"
#   associate_public_ip_address = "true"
#   private_ip = "10.2.1.100"
#   subnet_id = aws_subnet.idc-seoul.id
#   security_groups = [aws_security_group.idc-seoul.id]
#   tags = {
#     Name = "idc-seoul_db"
#   }
#   user_data = <<EOF
# #!/bin/bash
# hostnamectl --static set-hostname Seoul-IDC-DB
# yum install -y mariadb-server mariadb lynx
# systemctl start mariadb && systemctl enable mariadb
# echo -e "\n\nqwe123\nqwe123\ny\ny\ny\ny\n" | /usr/bin/mysql_secure_installation
# mysql -uroot -pqwe123 -e "CREATE DATABASE sample; GRANT ALL PRIVILEGES ON *.* TO 'admin'@'%' IDENTIFIED BY 'qwe123'; GRANT REPLICATION SLAVE ON *.* TO 'repl_user'@'%' IDENTIFIED BY 'qwe123'; flush privileges;"
# mysql -uroot -pqwe123 -e "USE sample;CREATE TABLE EMPLOYEES (ID int(11) UNSIGNED AUTO_INCREMENT PRIMARY KEY,NAME VARCHAR(45),ADDRESS VARCHAR(90));"
# cat <<EOT> /etc/my.cnf
# [mysqld]
# datadir=/var/lib/mysql
# socket=/var/lib/mysql/mysql.sock
# symbolic-links=0           
# log-bin=mysql-bin
# server-id=1
# [mysqld_safe]
# log-error=/var/log/mariadb/mariadb.log
# pid-file=/var/run/mariadb/mariadb.pid
# !includedir /etc/my.cnf.d
# EOT
# systemctl restart mariadb
# cat <<EOT> /home/ec2-user/list.txt
# 10.1.3.100
# web1.awsseoul.internal
# 10.1.4.100
# web2.awsseoul.internal
# 10.2.1.100
# db.idcseoul.internal
# 10.2.1.200
# dns.idcseoul.internal
# 10.3.3.100
# websrv1.awssinga.internal
# 10.4.1.100
# db.idcsinga.internal
# 10.4.1.200
# dns.idcsinga.internal
# EOT
#  cat <<EOT> /home/ec2-user/pingall.sh
#!/bin/bash
# date
# cat list.txt |  while read output
# do
#     ping -c 1 -W 1 "$output" > /dev/null
#     if [ $? -eq 0 ]; then
#     echo "host $output is up"
#     else
#     echo "host $output is down"
#     fi
# done
# EOT
# chmod +x /home/ec2-user/pingall.sh
# EOF
# }
##################################################################

/* Error: Self-referential block
    on idc_seoul/idc_seoul_instance.tf line 66, in resource "aws_instance" "idc-seoul_cgw":
    │   66:   leftid="${aws_instance.idc-seoul_cgw.public_ip}"
    │
    │ Configuration for aws_instance.idc-seoul_cgw may not refer to itself.
        문제점 : Instance가 생성되기 이전에 Public Ip를 참조하여 UserData에 사용하려고 함.
        해결방안 : ENI, EIP를 생성하여 UserData에 사용하도록 함. */
resource "aws_network_interface" "idc-seoul_cgw_eni" {
  provider          = aws.seoul
  subnet_id         = aws_subnet.idc-seoul.id
  private_ips       = ["10.2.1.50"]
  security_groups   = [aws_security_group.idc-seoul.id]

  tags = {
    Name = "idc-seoul_cgw_eni"
  }
}
resource "aws_eip" "idc-seoul_cgw_eip" { 
    provider = aws.seoul
    network_interface = aws_network_interface.idc-seoul_cgw_eni.id
} 
resource "aws_instance" "idc-seoul_cgw" {
  provider = aws.seoul
  ami           = var.seoul-ami
  instance_type = "t2.micro"
  network_interface {
    network_interface_id = aws_network_interface.idc-seoul_cgw_eni.id
    device_index = 0
  }
  tags = {
    Name = "idc-seoul_cgw"
  }
  user_data = <<EOE
#!/bin/bash
yum -y install tcpdump openswan
cat <<EOF>> /etc/sysctl.conf
net.ipv4.ip_forward=1
net.ipv4.conf.all.accept_redirects = 0
net.ipv4.conf.all.send_redirects = 0
net.ipv4.conf.default.send_redirects = 0
net.ipv4.conf.eth0.send_redirects = 0
net.ipv4.conf.default.accept_redirects = 0
net.ipv4.conf.eth0.accept_redirects = 0
net.ipv4.conf.ip_vti0.rp_filter = 0
net.ipv4.conf.eth0.rp_filter = 0
net.ipv4.conf.default.rp_filter = 0
net.ipv4.conf.all.rp_filter = 0
EOF
sysctl -p /etc/sysctl.conf
cat <<EOF> /etc/ipsec.d/aws.conf
conn Tunnel1
  authby=secret
  auto=start
  left=%defaultroute
  leftid=${aws_eip.idc-seoul_cgw_eip.public_ip}
  right="$word2"
  type=tunnel
  ikelifetime=8h
  keylife=1h
  phase2alg=aes128-sha1;modp1024
  ike=aes128-sha1;modp1024
  keyingtries=%forever
  keyexchange=ike
  leftsubnet=10.2.0.0/16
  rightsubnet=10.1.0.0/16
  dpddelay=10
  dpdtimeout=30
  dpdaction=restart_by_peer
EOF
cat <<EOF> /etc/ipsec.d/aws.secrets
${aws_eip.idc-seoul_cgw_eip.public_ip} $word2 : PSK "cloudneta"
EOF
systemctl start ipsec
systemctl enable ipsec
hostnamectl --static set-hostname IDC-CGW
EOE
}