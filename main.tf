terraform {
  required_providers {
    aws = {
      source = "hashicorp/aws"
      version = "3.47.0"
    }
  }
}

#ProviderBlockForAWS
provider "aws" {
  region = "ap-south-1"
}

#Creating VPC with cidr range
resource "aws_vpc" "my-vpc" {
  cidr_block       = var.my-vpc-cidr
  enable_dns_hostnames = true
  tags = {
    Name = "${var.env_prefix}-VPC"
  }
}

#Creating Public subnet with vpc id and subnet cidr
resource "aws_subnet" "Public_Subnet_1" {
  vpc_id     = aws_vpc.my-vpc.id
  cidr_block = var.pub_subnet_cidr[0]
  availability_zone = var.public_subnet_az[0]
  map_public_ip_on_launch = true

  tags = {
    Name = "${var.env_prefix}-Pub_subnet_1"
  }
}

#Creating Public subnet 2 with same vpc id and different subnet cidr
resource "aws_subnet" "Public_Subnet_2" {
  vpc_id     = aws_vpc.my-vpc.id
  cidr_block = var.pub_subnet_cidr[1]
  availability_zone = var.public_subnet_az[1]
  map_public_ip_on_launch = true
  tags = {
    Name = "${var.env_prefix}-Pub_subnet_2"
  }
}

#Creating Private subnet for our DB
resource "aws_subnet" "Private_Subnet_1" {
  vpc_id     = aws_vpc.my-vpc.id
  cidr_block = var.private_subnet_cidr[0]
  availability_zone = var.private_subnet_az[0]

  tags = {
    Name = "${var.env_prefix}-Private_subnet_1"
  }
}

#Creating Private subnet 2 for our DB
resource "aws_subnet" "Private_Subnet_2" {
  vpc_id     = aws_vpc.my-vpc.id
  cidr_block = var.private_subnet_cidr[1]
  availability_zone = var.private_subnet_az[1]


  tags = {
    Name = "${var.env_prefix}-Private_subnet_2"
  }
}

#Creating Internet Gateway for our VPC
resource "aws_internet_gateway" "igw" { 
  vpc_id = aws_vpc.my-vpc.id

  tags = {
    Name = "${var.env_prefix}-igw"
  }
}

#Creating Route Table to connect our VPC to internet gateway
resource "aws_route_table" "my-route-table"{
  vpc_id = aws_vpc.my-vpc.id

  route {
    cidr_block = var.route_table_cidr
    gateway_id = aws_internet_gateway.igw.id
  }

  tags = {
    Name = "${var.env_prefix}-route_table"
  }
}

#Associating our public subnet 1 with the route table
resource  "aws_route_table_association" "pub_subnet_route_association_A" {
  subnet_id = aws_subnet.Public_Subnet_1.id
  route_table_id = aws_route_table.my-route-table.id
}
#Associating our public subnet 2 with the route table
resource  "aws_route_table_association" "pub_subnet_route_association_B" {
  subnet_id = aws_subnet.Public_Subnet_2.id
  route_table_id = aws_route_table.my-route-table.id
}

#Creating Security group for our instances allowing http inbound
resource "aws_security_group" "my-sg" {
  vpc_id = aws_vpc.my-vpc.id

  ingress {
    from_port = 80
    to_port = 80
    protocol = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }
  egress {
    from_port = 0
    to_port = 0
    protocol = "-1"
    cidr_blocks = ["0.0.0.0/0"]
    prefix_list_ids = []
  }
   tags = {
    Name = "${var.env_prefix}-my-sg"
  }
}

#Fetching the EC2 AMI details from AWS using Data Source
data "aws_ami" "ami-amazon-linux" {
  most_recent      = true
  owners           = ["amazon"]
  filter {
    name   = "name"
    values = ["amzn2-ami-hvm-*-x86_64-gp2"]
  }

  filter {
    name   = "virtualization-type"
    values = ["hvm"]
  }
}

#Creating Our server in Public Subnet 1 using details gathered by data source
resource "aws_instance" "my-ec2-instance" {
  ami = data.aws_ami.ami-amazon-linux.id
  instance_type = var.ec2_instance_type
  availability_zone = var.public_subnet_az[0]
  vpc_security_group_ids = [aws_security_group.my-sg.id]
  subnet_id = aws_subnet.Public_Subnet_1.id
  associate_public_ip_address = true
   tags = {
    Name = "${var.env_prefix}-ec2-instance"
  }
}

#Creating Our server in Public Subnet 2 using details gathered by data source
resource "aws_instance" "my-ec2-instance2" {
  ami = data.aws_ami.ami-amazon-linux.id
  instance_type = var.ec2_instance_type
  availability_zone = var.public_subnet_az[1]
  vpc_security_group_ids = [aws_security_group.my-sg.id]
  subnet_id = aws_subnet.Public_Subnet_2.id
  associate_public_ip_address = true
   tags = {
    Name = "${var.env_prefix}-ec2-instance2"
  }
}


#Configuring Security group for our database instance
resource "aws_security_group" "my_db_sg" {
  vpc_id = aws_vpc.my-vpc.id

  ingress {
    from_port = 3306
    to_port = 3306
    protocol = "tcp"
    security_groups = [aws_security_group.my_alb_sg.id]
  }
  egress {
    from_port = 32768
    to_port = 65535
    protocol = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
    
  }
   tags = {
    Name = "${var.env_prefix}-my-db-sg"
  }
}

#configuring a security group to allow HTTP inbound traffic from our ALB 
resource "aws_security_group" "my_alb_sg" {
  vpc_id = aws_vpc.my-vpc.id

  ingress {
    from_port = 80
    to_port = 80
    protocol = "tcp"
    security_groups = [aws_security_group.my-sg.id]
  }
  egress {
    from_port = 0
    to_port = 0
    protocol = "-1"
    cidr_blocks = ["0.0.0.0/0"]
    
  }
   tags = {
    Name = "${var.env_prefix}-my-alb-sg"
  }
}

#Launchin ALB in Public Subnets
resource "aws_lb" "external-elb" {
  name               = "my-Ex-alb"
  internal           = false
  load_balancer_type = "application"
  security_groups    = [aws_security_group.my_alb_sg.id]
  subnets            = [aws_subnet.Public_Subnet_1.id, aws_subnet.Public_Subnet_2.id]

}

resource "aws_lb_target_group" "external-elb" {
  name     = "aws-lb-target-group"
  port     = 80
  protocol = "HTTP"
  vpc_id   = aws_vpc.my-vpc.id
}

# Configuring our ALB a target group that maps to our EC2 Instances.
resource "aws_lb_target_group_attachment" "external-elb1" {
  target_group_arn = aws_lb_target_group.external-elb.arn
  target_id        = aws_instance.my-ec2-instance.id
  port             = 80

  depends_on = [aws_instance.my-ec2-instance]
}

resource "aws_lb_target_group_attachment" "external-alb-2" {
  target_group_arn = aws_lb_target_group.external-elb.arn
  target_id        = aws_instance.my-ec2-instance2.id
  port             = 80

  depends_on = [aws_instance.my-ec2-instance2]
}

#Adding HTTP listner to ALB
resource "aws_lb_listener" "external-elb" {
  load_balancer_arn = aws_lb.external-elb.arn
  port              = "80"
  protocol          = "HTTP"

  default_action {
    type             = "forward"
    target_group_arn = aws_lb_target_group.external-elb.arn
  }
}

#Creating RDS instance
resource "aws_db_instance" "default" {
  allocated_storage    = 20
  db_subnet_group_name = "${aws_db_subnet_group.default.id}"
  engine               = "mysql"
  engine_version       = "8.0.23"
  instance_class       = "db.t2.micro"
  multi_az             =  true                
  name                 = "mydb"
  username             = "manish"
  password             = "password"
  skip_final_snapshot  = true
  vpc_security_group_ids = [aws_security_group.my_db_sg.id]
}

#RDS in Private Subnet
resource "aws_db_subnet_group" "default" {
  name       = "main"
  subnet_ids = [aws_subnet.Private_Subnet_1.id, aws_subnet.Private_Subnet_2.id]

  tags = {
    Name = "RDS subnet group"
  }
}