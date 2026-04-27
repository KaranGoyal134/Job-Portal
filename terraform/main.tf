provider "aws" {
  region = "us-east-1"
}

data "aws_availability_zones" "azs" {}

# -------------------------
# VPC
# -------------------------
resource "aws_vpc" "main" {
  cidr_block = "10.0.0.0/16"

  enable_dns_hostnames = true
  enable_dns_support   = true

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
# NAT Gateway (for private subnets)
# -------------------------
resource "aws_eip" "nat_eip" {
  domain = "vpc"

  tags = {
    Name = "job-portal-nat-eip"
  }

  depends_on = [aws_internet_gateway.igw]
}

resource "aws_nat_gateway" "nat" {
  allocation_id = aws_eip.nat_eip.id
  subnet_id     = aws_subnet.public_1.id

  tags = {
    Name = "job-portal-nat"
  }

  depends_on = [aws_internet_gateway.igw]
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

# Add NAT route to private route table
resource "aws_route" "private_nat" {
  route_table_id         = aws_route_table.private_rt.id
  destination_cidr_block = "0.0.0.0/0"
  nat_gateway_id         = aws_nat_gateway.nat.id
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

  ingress {
    from_port   = 4000
    to_port     = 4000
    protocol    = "tcp"
    cidr_blocks = ["10.0.0.0/16"]
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
  name     = "job-portal-tg"
  port     = 80
  protocol = "HTTP"
  vpc_id   = aws_vpc.main.id

  health_check {
    path                = "/"
    matcher             = "200-399"
    interval            = 30
    timeout             = 5
    healthy_threshold   = 2
    unhealthy_threshold = 3
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
# Launch Template
# -------------------------
resource "aws_launch_template" "lt" {
  name_prefix   = "job-portal-lt"
  image_id      = "ami-0ec10929233384c7f"
  instance_type = "t3.micro"

  iam_instance_profile {
    name = aws_iam_instance_profile.profile.name
  }

  user_data = base64encode(<<-USERDATA
#!/bin/bash

set -e
apt update -y
apt install -y docker.io docker-compose-plugin awscli amazon-ssm-agent

systemctl daemon-reload
systemctl enable amazon-ssm-agent
systemctl start amazon-ssm-agent

systemctl start docker
systemctl enable docker

usermod -aG docker ubuntu

# Retry logic for ECR login
MAX_RETRIES=5
RETRY_COUNT=0
until [ $RETRY_COUNT -ge $MAX_RETRIES ]; do
  aws ecr get-login-password --region us-east-1 \
   | docker login --username AWS --password-stdin \
  $(echo ${aws_ecr_repository.frontend.repository_url} | cut -d'/' -f1) && break
  RETRY_COUNT=$((RETRY_COUNT+1))
  if [ $RETRY_COUNT -lt $MAX_RETRIES ]; then
    sleep 10
  fi
done

if [ $RETRY_COUNT -eq $MAX_RETRIES ]; then
  echo "ECR login failed after $MAX_RETRIES attempts"
  exit 1
fi

# Fetch parameters from SSM
export DB_URL=$(aws ssm get-parameter --name "/job-portal/DB_URL" --with-decryption --query "Parameter.Value" --output text)
export JWT_SECRET=$(aws ssm get-parameter --name "/job-portal/JWT_SECRET_KEY" --with-decryption --query "Parameter.Value" --output text)
export CLOUDINARY_API_KEY=$(aws ssm get-parameter --name "/job-portal/CLOUDINARY_API_KEY" --with-decryption --query "Parameter.Value" --output text)
export CLOUDINARY_API_SECRET=$(aws ssm get-parameter --name "/job-portal/CLOUDINARY_API_SECRET" --with-decryption --query "Parameter.Value" --output text)
export CLOUDINARY_CLOUD_NAME=$(aws ssm get-parameter --name "/job-portal/CLOUDINARY_CLOUD_NAME" --with-decryption --query "Parameter.Value" --output text)

# Create docker-compose file
cat <<EOC > /home/ubuntu/docker-compose.yml
version: '3.8'

services:
  mongodb:
    image: mongo:7.0
    container_name: job-portal-mongodb
    restart: always
    volumes:
      - job-portal-data:/data/db
    networks:
      - job-portal-network
    healthcheck:
      test: echo 'db.runCommand("ping").ok' | mongosh localhost/test --quiet
      interval: 10s
      timeout: 5s
      retries: 5

  backend:
    image: ${aws_ecr_repository.backend.repository_url}:latest
    container_name: job-portal-backend
    restart: always
    environment:
      DB_URL: ${DB_URL}
      CLOUDINARY_API_KEY: ${CLOUDINARY_API_KEY}
      CLOUDINARY_API_SECRET: ${CLOUDINARY_API_SECRET}
      CLOUDINARY_CLOUD_NAME: ${CLOUDINARY_CLOUD_NAME}
      JWT_SECRET_KEY: ${JWT_SECRET}
      PORT: 4000
      FRONTEND_URL: http://${aws_lb.alb.dns_name}
      JWT_EXPIRE: 7d
      COOKIE_EXPIRE: 7
      NODE_ENV: production
    ports:
      - "4000:4000"
    depends_on:
      mongodb:
        condition: service_healthy
    networks:
      - job-portal-network
    healthcheck:
      test: curl -f http://localhost:4000/health || exit 1
      interval: 30s
      timeout: 10s
      retries: 3

  frontend:
    image: ${aws_ecr_repository.frontend.repository_url}:latest
    container_name: job-portal-frontend
    restart: always
    ports:
      - "80:80"
    environment:
      REACT_APP_API_URL: http://${aws_lb.alb.dns_name}
    depends_on:
      backend:
        condition: service_healthy
    networks:
      - job-portal-network
    healthcheck:
      test: curl -f http://localhost:80 || exit 1
      interval: 30s
      timeout: 10s
      retries: 3

volumes:
  job-portal-data:

networks:
  job-portal-network:
    driver: bridge
EOC

cd /home/ubuntu

# Wait for services to be ready (increased from 20s to 90s)
echo "Waiting for services to initialize..."
sleep 90

docker compose up -d

# Verify services are running
echo "Verifying services..."
sleep 30
docker compose ps

USERDATA
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

  target_group_arns          = [aws_lb_target_group.tg.arn]
  health_check_type         = "ELB"
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
output "nat_gateway_ip" {
  value       = aws_eip.nat_eip.public_ip
  description = "Public IP of NAT Gateway"
}

output "backend_ecr_url" {
  value = aws_ecr_repository.backend.repository_url
}

output "frontend_ecr_url" {
  value = aws_ecr_repository.frontend.repository_url
}

output "alb_dns" {
  value       = aws_lb.alb.dns_name
  description = "ALB DNS name - access application here"
}

output "asg_name" {
  value = aws_autoscaling_group.asg.name
}