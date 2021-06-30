env_prefix = "3-tier"
my-vpc-cidr ="10.0.0.0/16"
pub_subnet_cidr = ["10.0.1.0/24","10.0.2.0/24"]
public_subnet_az = ["ap-south-1a","ap-south-1b"]
private_subnet_az = ["ap-south-1a","ap-south-1b"]
private_subnet_cidr = ["10.0.3.0/24","10.0.4.0/24"]
route_table_cidr = "0.0.0.0/0"
ec2_instance_type = "t2.micro"