terraform {
  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 5.0"
    }
  }
}
  # Configure the AWS Provider
provider "aws" {
  region = "ap-south-1"
  }

#   # for stage management to store terraform.tfstate create one s3 bucket on aws
#   backend "s3" {
#     bucket = "terraform-task-1234567890"
#     key    = "terraform_task_file"
#     region = "ap-south-1"
# }
# Create VPC
resource "aws_vpc" "task_vpc" {
  cidr_block = "10.10.0.0/16"
  instance_tenancy = "default"
  enable_dns_support = true
  enable_dns_hostnames = true
  tags = {
    Name = "task_vpc"
  }
  
}

# Create private subnets in availability 1a creted for our both private ec2 and db instance 
resource "aws_subnet" "private_subnet_1a" {
  vpc_id = aws_vpc.task_vpc.id
  cidr_block = "10.10.1.0/24"
  availability_zone = "ap-south-1a"
  tags = {
    Name = "private_subnet_1a"
  }
}

# create aws public subnets in availability 1a created for bastion host
resource "aws_subnet" "public_subnet_1a" {
  vpc_id     = aws_vpc.task_vpc.id
  cidr_block = "10.10.0.0/24"
  availability_zone = "ap-south-1a"
  map_public_ip_on_launch = "true"
  tags = {
    Name = "public_subnet_1a"
  }
}

# create aws public subnets in availability 1b - this is created for alb needs atleast 2 AZs
resource "aws_subnet" "public_subnet_1b" {
  vpc_id     = aws_vpc.task_vpc.id
  cidr_block = "10.10.3.0/24"
  availability_zone = "ap-south-1b"
  map_public_ip_on_launch = "true"
  tags = {
    Name = "public_subnet_1b"
  }
}

# create aws private subnets in availability 1b - this is created for db needs atleast 2 AZs
resource "aws_subnet" "private_subnet_1b" {
  vpc_id     = aws_vpc.task_vpc.id
  cidr_block = "10.10.2.0/24"
  availability_zone = "ap-south-1b"
  tags = {
    Name = "public_subnet_1b"
  }
}
# Create security group for webapp instance
resource "aws_security_group" "webapp_sg" {
  name = "webapp_security_group"
  description = "allow ssh inbound traffic and all outbound traffic"
  vpc_id = aws_vpc.task_vpc.id
  tags = {
    Name = "webapp_sg"
  }
}
# Define ingress and egress rules
resource "aws_vpc_security_group_ingress_rule" "allow_ssh_ipv4" {
  security_group_id = aws_security_group.webapp_sg.id
  cidr_ipv4         = "0.0.0.0/0"
  from_port         = 22
  ip_protocol       = "tcp"
  to_port           = 22
}
resource "aws_vpc_security_group_ingress_rule" "allow_http_ipv4" {
  security_group_id = aws_security_group.webapp_sg.id
  cidr_ipv4         = "0.0.0.0/0"
  from_port         = 80
  ip_protocol       = "tcp"
  to_port           = 80
}
resource "aws_vpc_security_group_egress_rule" "allow_all_traffic_ipv4" {
  security_group_id = aws_security_group.webapp_sg.id
  cidr_ipv4         = "0.0.0.0/0"
  ip_protocol       = "-1" # semantically equivalent to all ports
}


# Create a DB Subnet Group
resource "aws_db_subnet_group" "my_db_subnet_group" {
  name       = "my-db-subnet-group"
  subnet_ids = [aws_subnet.private_subnet_1a.id, aws_subnet.private_subnet_1b.id]

  tags = {
    Name = "MyDBSubnetGroup"
  }
}


# Create a Security Group for the RDS instance
resource "aws_security_group" "dbinstance_sg" {
  name        = "allow_postgres"
  description = "Allow PostgreSQL traffic"
  vpc_id      = aws_vpc.task_vpc.id
  tags = {
    Name = "dbinstance_sg"
  }
}

# Define ingress and egress rules
resource "aws_vpc_security_group_ingress_rule" "allow_postgresql_rule_ipv4" {
  security_group_id = aws_security_group.dbinstance_sg.id
  description = "Allow PostgreSQL from webapp"
  cidr_ipv4   = "0.0.0.0/0"
  from_port   = 5432
  ip_protocol = "tcp"
  to_port     = 5432
}
resource "aws_vpc_security_group_ingress_rule" "allow_postgresql_private_rule_ipv4" {
  security_group_id = aws_security_group.dbinstance_sg.id
  description = "Allow PostgreSQL from private subnet"
  cidr_ipv4   = "${data.aws_instance.my_instance.private_ip}/32" # Allow from webapp instance
  from_port   = 5432
  ip_protocol = "tcp"
  to_port     = 5432

}
data "aws_instance" "my_instance" {
  instance_id = aws_instance.webapp_instance.id # Replace with the actual instance ID
}

output "webapp_instance_private_ip" {
  value = aws_instance.webapp_instance.private_ip
}

# data "aws_instance" {


# }
resource "aws_vpc_security_group_egress_rule" "allow_all_traffic_postgresql_ipv4" {
  security_group_id = aws_security_group.dbinstance_sg.id
  cidr_ipv4         = "0.0.0.0/0"
  ip_protocol       = "-1" # semantically equivalent to all ports
}

# Create security group for ALB
resource "aws_security_group" "alb_sg" {
  name = "alb_security_group"
  description = "allow ssh inbound traffic and all outbound traffic"
  vpc_id = aws_vpc.task_vpc.id
  tags = {
    Name = "alb_security_group"
  }
}
# Define ingress and egress rules
resource "aws_vpc_security_group_ingress_rule" "allow_alb_http_ipv4" {
  security_group_id = aws_security_group.alb_sg.id
  cidr_ipv4         = "0.0.0.0/0"
  from_port         = 80
  ip_protocol       = "tcp"
  to_port           = 80
}
resource "aws_vpc_security_group_egress_rule" "allow_all_alb_traffic_ipv4" {
  security_group_id = aws_security_group.alb_sg.id
  cidr_ipv4         = "0.0.0.0/0"
  ip_protocol       = "-1" # semantically equivalent to all ports
}

# Create security group for bastion host instance
resource "aws_security_group" "bastion_sg" {
  name = "bastion_security_group"
  vpc_id = aws_vpc.task_vpc.id
  tags = {
    Name = "bastion_sg"
  }
  
}

# Define ingress and egress rules
resource "aws_vpc_security_group_ingress_rule" "allow_bastion_ssh_ipv4" {
  security_group_id = aws_security_group.bastion_sg.id
  cidr_ipv4         = "0.0.0.0/0"
  from_port         = 22
  ip_protocol       = "tcp"
  to_port           = 22
}
resource "aws_vpc_security_group_ingress_rule" "allow_bastion_http_rule_ipv4" {
  security_group_id = aws_security_group.bastion_sg.id
  cidr_ipv4         = "0.0.0.0/0"
  from_port         = 80
  ip_protocol       = "tcp"
  to_port           = 80
}
resource "aws_vpc_security_group_egress_rule" "allow_all_bastion_traffic_ipv4" {
  security_group_id = aws_security_group.bastion_sg.id
  cidr_ipv4         = "0.0.0.0/0"
  ip_protocol       = "-1" # semantically equivalent to all ports
}


# Create NAT Gateway
resource "aws_eip" "nat_eip" {

  tags = {
    Name = "nat_eip"
  }
}

resource "aws_nat_gateway" "nat_gw" {
  allocation_id = aws_eip.nat_eip.id
  subnet_id     = aws_subnet.public_subnet_1a.id
  tags = {
    Name = "nat_gw"
  }
}
# create private route table for private subnet
resource "aws_route_table" "private_RT" {
  vpc_id = aws_vpc.task_vpc.id
  route {
  cidr_block     = "0.0.0.0/0"
  nat_gateway_id = aws_nat_gateway.nat_gw.id
  }
  tags = {
    Name = "private_RT"
  }
}

# output "nat_gw_id" {
#   value = aws_nat_gateway.nat_gw.id
# }

# provite private Route table association
resource "aws_route_table_association" "RT_association_3" {
  subnet_id      = aws_subnet.private_subnet_1a.id
  route_table_id = aws_route_table.private_RT.id
}

# create public route table
resource "aws_route_table" "public_RT" {
  vpc_id = aws_vpc.task_vpc.id

  route {
    cidr_block = "0.0.0.0/0"
    gateway_id = aws_internet_gateway.task_IGW.id
  }
  tags = {
    Name = "public_RT"
  }
}

# create internet gateway
resource "aws_internet_gateway" "task_IGW" {
  vpc_id = aws_vpc.task_vpc.id
  tags = {
    Name = "task_IGW"
  }

}
# provide public Route table association
resource "aws_route_table_association" "RT_association_1" {
  subnet_id      = aws_subnet.public_subnet_1a.id
  route_table_id = aws_route_table.public_RT.id
}

# create target group
resource "aws_lb_target_group" "task_TG" {
  name     = "targetgroup1"
  port     = 80
  protocol = "HTTP"
  vpc_id   = aws_vpc.task_vpc.id
  tags = {
    Name = "task_TG"
  }
}

resource "aws_lb_target_group_attachment" "target_group_attach_alb" {
  target_group_arn = aws_lb_target_group.task_TG.arn
  target_id        = aws_instance.webapp_instance.id
  port             = 80
}
# create lisener for ALB
resource "aws_lb_listener" "lb_lisener" {
  load_balancer_arn = aws_lb.apache_LB.arn
  port              = "80"
  protocol          = "HTTP"

  default_action {
    type             = "forward"
    target_group_arn = aws_lb_target_group.task_TG.arn
  }
  tags = {
    Name = "lb_lisener"
  }
}
# create application load balancer
resource "aws_lb" "apache_LB" {
  name               = "apache-LB"
  internal           = false
  load_balancer_type = "application"
  security_groups    = [aws_security_group.alb_sg.id]
  subnets            = [aws_subnet.public_subnet_1a.id, aws_subnet.public_subnet_1b.id]
#enable_deletion_protection = true

  tags = {
    Environment = "production"
  }
}


# Launch EC2 instances in private subnet
resource "aws_instance" "webapp_instance" {
  ami           = "ami-0f58b397bc5c1f2e8"
  instance_type = "t2.micro"
  key_name = aws_key_pair.task_key_pair_1.id
  subnet_id = aws_subnet.private_subnet_1a.id
  vpc_security_group_ids = [aws_security_group.webapp_sg.id]
  user_data = filebase64("userdata_webapp.sh")
  
  tags = {
    Name = "webapp_instance"
  }
  # Define user data for configuring the web application
}

# resource "aws_instance" "db_instance" {
#   ami           = "ami-0f58b397bc5c1f2e8"
#   instance_type = "t2.micro"
#   key_name = aws_key_pair.task_key_pair_1.id
#   subnet_id = aws_subnet.private_subnet_1a.id
#   vpc_security_group_ids = [aws_security_group.webapp_sg.id]
#   user_data = filebase64("userdata_dbinstance.sh")

#   tags = {
#     Name = "db_instance"
#   }
#  
# }

# Create a Custom DB Parameter Group
# resource "aws_db_parameter_group" "my_postgres_parameter_group" {
#   name        = "my-postgres-parameter-group"
#   family      = "postgres13"
#   description = "Custom parameter group for PostgreSQL 13"

#   parameter {
#     name  = "shared_buffers"
#     value = "utf8"
#   }

#   tags = {
#     Name = "MyPostgresParameterGroup"
#   }
# }
 # Define user data for configuring PostgreSQL
resource "aws_db_instance" "my_postgresql_instance" {
  allocated_storage      = 10
  storage_type           = "gp2"
  engine                 = "postgres"
  engine_version         = "14"
  db_subnet_group_name   = aws_db_subnet_group.my_db_subnet_group.name
  instance_class         = "db.t3.small"
  username               = "postgresql"
  password               = "postgresql123"
  #parameter_group_name   = aws_db_parameter_group.my_postgres_parameter_group.name
  skip_final_snapshot    = true
  publicly_accessible    = false
  vpc_security_group_ids = [aws_security_group.dbinstance_sg.id]  # Replace with your security group ID
  #apply_immediately      = false

tags = {
    Name = "my_postgresql_instance"
  }
}

# create aws key pair
resource "aws_key_pair" "task_key_pair_1" {
  key_name   = "task_key_pair_1"
  public_key = "ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAIGdHXrXZ4Owu834k34UkBs+obIUWew5JoW+IOg1EblEw HP@DESKTOP-BCJC7SG"
  }


# Set up bastion host
# Launch EC2 instances in public subnet
resource "aws_instance" "bastion_host" {
  ami           = "ami-0f58b397bc5c1f2e8"
  instance_type = "t2.micro"
  key_name = aws_key_pair.task_key_pair_1.id
  subnet_id = aws_subnet.public_subnet_1a.id
  vpc_security_group_ids = [aws_security_group.bastion_sg.id]
  user_data = filebase64("userdata_webapp.sh")

tags = {
    Name = "bastion_host"
  }
}

# Define bastion host configuration


