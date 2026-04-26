provider "aws" {
  region = "us-east-1"
}

data "aws_availability_zones" "azs" {}

# -------------------------
# VPC
# -------------------------
resource "aws_vpc" "main" {
  cidr_block = "10.0.0.0/16"

  tags = {
    Name = "job-portal-vpc"
  }
}

# -------------------------
# Subnets (Multi-AZ)
# -------------------------
resource "aws_subnet" "public_1" {
  vpc_id                  = aws_vpc.main.id
  cidr_block              = "10.0.1.0/24"
  availability_zone       = data.aws_availability_zones.azs.names[0]
  map_public_ip_on_launch = true
}

resource "aws_subnet" "public_2" {
  vpc_id                  = aws_vpc.main.id
  cidr_block              = "10.0.2.0/24"
  availability_zone       = data.aws_availability_zones.azs.names[1]
  map_public_ip_on_launch = true
}

resource "aws_subnet" "private_1" {
  vpc_id            = aws_vpc.main.id
  cidr_block        = "10.0.3.0/24"
  availability_zone = data.aws_availability_zones.azs.names[0]
}

resource "aws_subnet" "private_2" {
  vpc_id            = aws_vpc.main.id
  cidr_block        = "10.0.4.0/24"
  availability_zone = data.aws_availability_zones.azs.names[1]
}

# -------------------------
# Internet Gateway
# -------------------------
resource "aws_internet_gateway" "igw" {
  vpc_id = aws_vpc.main.id
}

# -------------------------
# Route Table (Public)
# -------------------------
resource "aws_route_table" "public_rt" {
  vpc_id = aws_vpc.main.id
}

resource "aws_route_table" "private_rt" {
  vpc_id = aws_vpc.main.id
}

resource "aws_route_table_association" "private_assoc_1" {
  subnet_id      = aws_subnet.private_1.id
  route_table_id = aws_route_table.private_rt.id
}

resource "aws_route_table_association" "private_assoc_2" {
  subnet_id      = aws_subnet.private_2.id
  route_table_id = aws_route_table.private_rt.id
}

resource "aws_route" "internet" {
  route_table_id         = aws_route_table.public_rt.id
  destination_cidr_block = "0.0.0.0/0"
  gateway_id             = aws_internet_gateway.igw.id
}

resource "aws_route_table_association" "public_assoc_1" {
  subnet_id      = aws_subnet.public_1.id
  route_table_id = aws_route_table.public_rt.id
}

resource "aws_route_table_association" "public_assoc_2" {
  subnet_id      = aws_subnet.public_2.id
  route_table_id = aws_route_table.public_rt.id
}

# -------------------------
# VPC Endpoints (NO NAT)
# -------------------------
resource "aws_security_group" "vpce_sg" {
  vpc_id = aws_vpc.main.id

  ingress {
    from_port       = 443
    to_port         = 443
    protocol        = "tcp"
    security_groups = [aws_security_group.ec2_sg.id]
  }
}

resource "aws_vpc_endpoint" "ecr_api" {
  vpc_id              = aws_vpc.main.id
  service_name        = "com.amazonaws.us-east-1.ecr.api"
  vpc_endpoint_type   = "Interface"
  subnet_ids          = [aws_subnet.private_1.id, aws_subnet.private_2.id]
  security_group_ids  = [aws_security_group.vpce_sg.id]
}

resource "aws_vpc_endpoint" "ecr_dkr" {
  vpc_id              = aws_vpc.main.id
  service_name        = "com.amazonaws.us-east-1.ecr.dkr"
  vpc_endpoint_type   = "Interface"
  subnet_ids          = [aws_subnet.private_1.id, aws_subnet.private_2.id]
  security_group_ids  = [aws_security_group.vpce_sg.id]
}

resource "aws_vpc_endpoint" "s3" {
  vpc_id       = aws_vpc.main.id
  service_name = "com.amazonaws.us-east-1.s3"

  route_table_ids = [
    aws_route_table.public_rt.id,
    aws_route_table.private_rt.id   
  ]
}

resource "aws_vpc_endpoint" "ssm" {
  vpc_id            = aws_vpc.main.id
  service_name      = "com.amazonaws.us-east-1.ssm"
  vpc_endpoint_type = "Interface"
  subnet_ids        = [aws_subnet.private_1.id, aws_subnet.private_2.id]
  security_group_ids = [aws_security_group.vpce_sg.id]
}

resource "aws_vpc_endpoint" "ssmmessages" {
  vpc_id            = aws_vpc.main.id
  service_name      = "com.amazonaws.us-east-1.ssmmessages"
  vpc_endpoint_type = "Interface"
  subnet_ids        = [aws_subnet.private_1.id, aws_subnet.private_2.id]
  security_group_ids = [aws_security_group.vpce_sg.id]
}

resource "aws_vpc_endpoint" "ec2messages" {
  vpc_id            = aws_vpc.main.id
  service_name      = "com.amazonaws.us-east-1.ec2messages"
  vpc_endpoint_type = "Interface"
  subnet_ids        = [aws_subnet.private_1.id, aws_subnet.private_2.id]
  security_group_ids = [aws_security_group.vpce_sg.id]
}

# -------------------------
# ECR
# -------------------------
resource "aws_ecr_repository" "frontend" {
  name         = "job-portal-frontend"
  force_delete = true
}

resource "aws_ecr_repository" "backend" {
  name         = "job-portal-backend"
  force_delete = true
}

# -------------------------
# Security Groups
# -------------------------
resource "aws_security_group" "alb_sg" {
  vpc_id = aws_vpc.main.id

  ingress {
    from_port   = 80
    to_port     = 80
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }
}

resource "aws_security_group" "ec2_sg" {
  vpc_id = aws_vpc.main.id

  ingress {
    from_port       = 80
    to_port         = 80
    protocol        = "tcp"
    security_groups = [aws_security_group.alb_sg.id]
  }

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }
}

# -------------------------
# ALB
# -------------------------
resource "aws_lb" "alb" {
  name               = "job-portal-alb"
  load_balancer_type = "application"
  subnets            = [aws_subnet.public_1.id, aws_subnet.public_2.id]
  security_groups    = [aws_security_group.alb_sg.id]
}

resource "aws_lb_target_group" "tg" {
  port     = 80
  protocol = "HTTP"
  vpc_id   = aws_vpc.main.id

health_check {
  path                = "/"
  matcher             = "200-399"
  interval            = 30
  timeout             = 5
  healthy_threshold   = 2
  unhealthy_threshold = 5
}
}

resource "aws_lb_listener" "listener" {
  load_balancer_arn = aws_lb.alb.arn
  port              = 80

  default_action {
    type             = "forward"
    target_group_arn = aws_lb_target_group.tg.arn
  }
}

# -------------------------
# IAM
# -------------------------
resource "aws_iam_role" "ec2_role" {
  name = "job-portal-ec2-role"

  assume_role_policy = jsonencode({
    Version = "2012-10-17",
    Statement = [{
      Action = "sts:AssumeRole",
      Effect = "Allow",
      Principal = { Service = "ec2.amazonaws.com" }
    }]
  })
}

resource "aws_iam_role_policy_attachment" "ssm_access" {
  role       = aws_iam_role.ec2_role.name
  policy_arn = "arn:aws:iam::aws:policy/AmazonSSMManagedInstanceCore"
}

resource "aws_iam_role_policy_attachment" "ecr_access" {
  role       = aws_iam_role.ec2_role.name
  policy_arn = "arn:aws:iam::aws:policy/AmazonEC2ContainerRegistryReadOnly"
}

resource "aws_iam_instance_profile" "profile" {
  role = aws_iam_role.ec2_role.name
}

# -------------------------
# AMI (Ubuntu)
# -------------------------
data "aws_ami" "ubuntu" {
  most_recent = true

  owners = ["099720109477"]

  filter {
    name   = "name"
    values = ["ubuntu/images/hvm-ssd/ubuntu-jammy-22.04-amd64-server-*"]
  }
}

# -------------------------
# Launch Template
# -------------------------
resource "aws_launch_template" "lt" {
  name_prefix   = "job-portal-lt"
  image_id      = data.aws_ami.ubuntu.id
  instance_type = "t3.micro"

  iam_instance_profile {
    name = aws_iam_instance_profile.profile.name
  }

  user_data = base64encode(<<EOF
#!/bin/bash

set -e
apt update -y
apt install -y docker.io docker-compose-plugin awscli

systemctl start docker
systemctl enable docker

# Login to ECR (use frontend repo just to get registry)
aws ecr get-login-password --region us-east-1 \
 | docker login --username AWS --password-stdin \
$(echo ${aws_ecr_repository.frontend.repository_url} | cut -d'/' -f1)
DB_URL=$(aws ssm get-parameter --name "/job-portal/DB_URL" --with-decryption --query "Parameter.Value" --output text)
JWT_SECRET=$(aws ssm get-parameter --name "/job-portal/JWT_SECRET_KEY" --with-decryption --query "Parameter.Value" --output text)
CLOUDINARY_API_KEY=$(aws ssm get-parameter --name "/job-portal/CLOUDINARY_API_KEY" --with-decryption --query "Parameter.Value" --output text)
CLOUDINARY_API_SECRET=$(aws ssm get-parameter --name "/job-portal/CLOUDINARY_API_SECRET" --with-decryption --query "Parameter.Value" --output text)
CLOUDINARY_CLOUD_NAME=$(aws ssm get-parameter --name "/job-portal/CLOUDINARY_CLOUD_NAME" --with-decryption --query "Parameter.Value" --output text)

# Create docker-compose file
cat <<EOC > /home/ubuntu/docker-compose.yml

services:
  backend:
    restart: always
    image: ${aws_ecr_repository.backend.repository_url}:latest
    ports:
      - "4000:4000"
    environment:
      DB_URL: $${DB_URL}
      CLOUDINARY_API_KEY: $${CLOUDINARY_API_KEY}
      CLOUDINARY_API_SECRET: $${CLOUDINARY_API_SECRET}
      CLOUDINARY_CLOUD_NAME: $${CLOUDINARY_CLOUD_NAME}
      JWT_SECRET_KEY: $${JWT_SECRET}
      PORT: 4000
      FRONTEND_URL: http://${aws_lb.alb.dns_name}
      JWT_EXPIRE: 7d
      COOKIE_EXPIRE: 7
      NODE_ENV: production
    depends_on:
      - mongodb

  frontend:
    restart: always
    image: ${aws_ecr_repository.frontend.repository_url}:latest
    ports:
      - "80:80"
    environment:
      REACT_APP_API_URL: http://backend:4000
    depends_on:
      - backend

  mongodb:
    restart: always
    image: mongo:latest
    volumes:
      - job-portal-data:/data/db

volumes:
  job-portal-data:
EOC

cd /home/ubuntu
sleep 20
docker compose up -d
EOF
)

  network_interfaces {
    associate_public_ip_address = false
    security_groups = [aws_security_group.ec2_sg.id]
  }
}

# -------------------------
# ASG
# -------------------------
resource "aws_autoscaling_group" "asg" {
  name             = "job-portal-asg"
  desired_capacity = 2
  max_size         = 4
  min_size         = 1

  vpc_zone_identifier = [
    aws_subnet.private_1.id,
    aws_subnet.private_2.id
  ]

  launch_template {
    id      = aws_launch_template.lt.id
    version = "$Latest"
  }

  target_group_arns = [aws_lb_target_group.tg.arn]
  health_check_grace_period = 300
}

# -------------------------
# Scaling Policy
# -------------------------
resource "aws_autoscaling_policy" "cpu" {
  name                   = "cpu-scaling"
  policy_type            = "TargetTrackingScaling"
  autoscaling_group_name = aws_autoscaling_group.asg.name

  target_tracking_configuration {
    target_value = 75.0

    predefined_metric_specification {
      predefined_metric_type = "ASGAverageCPUUtilization"
    }
  }
}

# -------------------------
# Outputs
# -------------------------
output "frontend_ecr_url" {
  value = aws_ecr_repository.frontend.repository_url
}

output "backend_ecr_url" {
  value = aws_ecr_repository.backend.repository_url
}

output "asg_name" {
  value = aws_autoscaling_group.asg.name
}

output "alb_dns" {
  value = aws_lb.alb.dns_name
}