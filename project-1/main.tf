# Configure the AWS Provider
# Terraform website has documentation with templates for what you are looking for and trying to deploy.
provider "aws" {
  region = "us-east-1"
# I added static credentials (This is the wrong way to do it since if I push to Github everyone will have access to my keys! Which is a huge NONO- this comprimises security)
  access_key = "my-acces-key"
  secret_key = "my-secret-key"
}

/*
Creating a webserver with terraform project
Steps:
1. Create Vpc
2. Create Internet Gateway
3. Create Custom route table
4. Create a Subnet
5. Associate subnet with route table
6. Create Security group to allow port 20,80,443
7. Create a network interface with an ip in the subnet that was created in step 4
8. Assign an elastic IP to the network interface created in step 7
9. Create AL2 server and install/enable apache2
*/

# 1. Create Vpc
resource "aws_vpc" "my-terraform-vpc" {
  cidr_block = "10.0.0.0/16"
  tags = {
    Name = "production"
  }
}

# 2. Create Internet Gateway
resource "aws_internet_gateway" "gw" {
  vpc_id = aws_vpc.my-terraform-vpc.id

  tags = {
    Name = "prod-gw"
  }
}

# 3. Create Custom route table
resource "aws_route_table" "my-terraform-route-table" {
  vpc_id = aws_vpc.my-terraform-vpc.id

  route {
    cidr_block = "0.0.0.0/0"
    gateway_id = aws_internet_gateway.gw.id
  }

  route {
    ipv6_cidr_block = "::/0"
    gateway_id      = aws_internet_gateway.gw.id
  }

  tags = {
    Name = "prod-route-table"
  }
}

# 4. Create a Subnet
resource "aws_subnet" "my-terraform-subnet1" {
  vpc_id     = aws_vpc.my-terraform-vpc.id
  cidr_block = "10.0.1.0/24"
  availability_zone = "us-east-1a"

  tags = {
    Name = "prod-subnet"
  }
}

# 5. Associate subnet with route table
resource "aws_route_table_association" "my-terraform-route-table-association" {
  subnet_id      = aws_subnet.my-terraform-subnet1.id
  route_table_id = aws_route_table.my-terraform-route-table.id
}

# 6. Create Security group to allow port 20,80,443
resource "aws_security_group" "my-terraform-security-group" {
  name        = "my-terraform-security-group"
  description = "Allow web traffic"
  vpc_id      = aws_vpc.my-terraform-vpc.id

  ingress {
    description      = "HTTPS"
    from_port        = 443
    to_port          = 443
    protocol         = "tcp"
    cidr_blocks      = ["0.0.0.0/0"]
  }

  ingress {
    description      = "HTTP"
    from_port        = 80
    to_port          = 80
    protocol         = "tcp"
    cidr_blocks      = ["0.0.0.0/0"]
  }

  ingress {
    description      = "SSH"
    from_port        = 22
    to_port          = 22
    protocol         = "tcp"
    cidr_blocks      = ["0.0.0.0/0"]
  }

  egress {
    from_port        = 0
    to_port          = 0
    protocol         = "-1"
    cidr_blocks      = ["0.0.0.0/0"]
    ipv6_cidr_blocks = ["::/0"]
  }

  tags = {
    Name = "allow_web"
  }
}

# 7. Create a network interface with an ip in the subnet that was created in step 4
resource "aws_network_interface" "my-terraform-network-interface" {
  subnet_id       = aws_subnet.my-terraform-subnet1.id
  private_ips     = ["10.0.1.50"]
  security_groups = [aws_security_group.my-terraform-security-group.id]

}

# 8. Assign an elastic IP to the network interface created in step 7
resource "aws_eip" "one" {
  vpc                       = true
  network_interface         = aws_network_interface.my-terraform-network-interface.id
  associate_with_private_ip = "10.0.1.50"
  depends_on = [aws_internet_gateway.gw] # we didn't do '.id' because we want to reference the whole resource not the id
}

# 9. Create AL2 server and install/enable apache2
resource "aws_instance" "my-terraform-server" {
  ami           = "ami-026b57f3c383c2eec"
  instance_type = "t2.micro"
  availability_zone = "us-east-1a" #you want to hardcode the AZ for subnet and ec2 so they are created in the same az and go together
  key_name = "main-key"

  network_interface {
    device_index = 0
    network_interface_id = aws_network_interface.my-terraform-network-interface.id
  }

  user_data = <<-EOF
    #!/bin/bash
    # Use this for your user data (script from top to bottom)
    # install httpd (Linux 2 version)
    yum update -y
    yum install -y httpd
    systemctl start httpd
    systemctl enable httpd
    echo "<h1>Hello World from $(hostname -f)</h1>" > /var/www/html/index.html
    EOF
  tags = {
    Name = "Al2-server"
  }
}  

# Additional subnet and ec2 for resiliency
/* resource "aws_subnet" "my-terraform-subnet2" {
  vpc_id     = aws_vpc.my-terraform-vpc.id
  cidr_block = "10.0.1.0/24"
  availability_zone = "us-west-1a"

  tags = {
    Name = "prod-subnet2"
  }
}




resource "aws_instance" "my-backup-terraform-server" {
  ami           = "ami-026b57f3c383c2eec"
  instance_type = "t2.micro"
  availability_zone = "us-west-1a" #you want to hardcode the AZ for subnet and ec2 so they are created in the same az and go together
  key_name = "main-key"

  network_interface {
    device_index = 0
    network_interface_id = aws_network_interface.my-terraform-network-interface.id
  }

  user_data = <<-EOF
    #!/bin/bash
    # Use this for your user data (script from top to bottom)
    # install httpd (Linux 2 version)
    yum update -y
    yum install -y httpd
    systemctl start httpd
    systemctl enable httpd
    echo "<h1>Hello World from $(hostname -f)</h1>" > /var/www/html/index.html
    EOF
  tags = {
    Name = "Al2-server2"
  }
}  

*/





/*

# Creating a VPC
resource "aws_vpc" "my-terraform-vpc" {
  cidr_block = "10.0.0.0/16"
  tags = {
    Name = "production"
  }
}

# Creating a subnet
resource "aws_subnet" "my-terraform-subnet1" {
  #note we haven't created the vpc_id yet so we are going to reference the one we are making via terraform to the space below (put 'aws_vpc' + name + '.id')
  vpc_id     = aws_vpc.my-terraform-vpc.id
  cidr_block = "10.0.1.0/24"

  tags = {
    Name = "prod-subnet"
  }
}



# How to create resources in a provider
resource "<provider>_<resource_type" "name" {
    config options.....
    key = "value"
    keys2 = "another value"
  }

resource "aws_instance" "my-terraform-server" {
  ami           = "ami-026b57f3c383c2eec"
  instance_type = "t2.micro"

  tags = {
    # Name = "linux"
  }
}  

*/