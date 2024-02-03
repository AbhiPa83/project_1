resource "aws_internet_gateway_attachment" "igw_1" {
  internet_gateway_id = aws_internet_gateway.test_project_igw_1.id
  vpc_id              = aws_vpc.test_project_vpc_1.id
}

resource "aws_vpc" "test_project_vpc_1" {
  cidr_block = "10.0.0.0/16"
  enable_dns_support   = true
  enable_dns_hostnames = true
}

resource "aws_internet_gateway" "test_project_igw_1" {}

resource "aws_subnet" "test_project_subnet_1a" {
  vpc_id     = aws_vpc.test_project_vpc_1.id
  cidr_block = "10.1.0.0/24"
  availability_zone = "ap-south-1a"

  tags = {
    Name = "test_project_subnet_1a"
  }
}

resource "aws_subnet" "test_project_subnet_1b" {
  vpc_id     = aws_vpc.test_project_vpc_1.id
  cidr_block = "10.2.0.0/24"
  availability_zone = "ap-south-1b"

  tags = {
    Name = "test_project_subnet_1b"
  }
}

resource "aws_route_table" "test_project_rt_public" {
  vpc_id = aws_vpc.test_project_vpc_1.id

  tags = {
    Name = "Route_Table"
  }
}

resource "aws_route" "public_access_route" {
  route_table_id         = aws_route_table.test_project_rt_public.id
  destination_cidr_block = "0.0.0.0/0"
  gateway_id             = aws_internet_gateway.test_project_igw_1.id
}

resource "aws_route_table_association" "test_project_association_1a" {
  subnet_id      = aws_subnet.test_project_subnet_1a.id
  route_table_id = aws_route_table.test_project_rt_public.id
}

resource "aws_route_table_association" "test_project_association_1b" {
  subnet_id      = aws_subnet.test_project_subnet_1b.id
  route_table_id = aws_route_table.test_project_rt_public.id
}

resource "aws_security_group" "test-project-lb-sg-http" {
  description = "To Allow HTTP traffic for Load Balancer"
  vpc_id      = aws_vpc.test_project_vpc_1.id

  ingress {
    from_port   = 80
    to_port     = 80
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

}

resource "aws_security_group" "test-project-ec2-sg-http-ssh" {
  description = "To Allow HTTP and SSH access for EC2"
  vpc_id      = aws_vpc.test_project_vpc_1.id

  ingress {
    from_port   = 22
    to_port     = 22
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  ingress {
    from_port   = 80
    to_port     = 80
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

}

output "security_group_id" {
  value = aws_security_group.test-project-ec2-sg-http-ssh.id
}

resource "aws_lb_target_group" "test-project-tg-ec2" {
  name        = "Target-group"
  port        = 80
  protocol    = "HTTP"
  vpc_id      = aws_vpc.test_project_vpc_1.id
  target_type = "instance"

  health_check {
    path                = "/"
    port                = "traffic-port"
    protocol            = "HTTP"
    healthy_threshold   = 2
    unhealthy_threshold = 2
    timeout             = 3
    interval            = 300
  }
}

resource "aws_lb" "test-project-lb-ec2" {
  name               = "application-lb"
  internal           = false
  load_balancer_type = "application"
  security_groups    = [aws_security_group.test-project-lb-sg-http.id]
  subnets            = [aws_subnet.test_project_subnet_1a.id, aws_subnet.test_project_subnet_1b.id]

  enable_deletion_protection = false

  enable_cross_zone_load_balancing = true
  enable_http2                     = true

  tags = {
    Name = "application-lb"
  }
}

# Create listener pointing to the target group
resource "aws_lb_listener" "alb_to_tg_listener" {
  load_balancer_arn = aws_lb.test-project-lb-ec2.arn
  port              = 80
  protocol          = "HTTP"

  default_action {
    type             = "forward"
    target_group_arn = aws_lb_target_group.test-project-tg-ec2.arn
  }
}

resource "aws_launch_template" "test-project-lt_ec2" {
  name = "test-project-lt_ec2"
  image_id = "ami-03f4878755434977f"
  instance_type = "t2.micro"
  key_name = "Test_projects"
  vpc_security_group_ids = [aws_security_group.test-project-ec2-sg-http-ssh.id]
  network_interfaces {
    associate_public_ip_address = true
  }
}

resource "aws_autoscaling_group" "test-project-asg-ec2" {
  availability_zones = ["ap-south-1a"]
  desired_capacity   = 2
  max_size           = 3
  min_size           = 1

  launch_template {
    id      = aws_launch_template.test-project-lt_ec2.id
    version = "$Latest"
  }
}
