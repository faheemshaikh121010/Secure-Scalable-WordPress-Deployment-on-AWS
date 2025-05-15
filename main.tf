# main.tf
provider "aws" {
  region = "us-east-1"
}

module "vpc" {
  source  = "terraform-aws-modules/vpc/aws"
  version = "5.0.0"

  name = "wordpress-vpc"
  cidr = "10.0.0.0/16"

  azs             = ["us-east-1a", "us-east-1b"]
  public_subnets  = ["10.0.1.0/24", "10.0.2.0/24"]
  private_subnets = ["10.0.3.0/24", "10.0.4.0/24"]

  enable_nat_gateway   = true
  single_nat_gateway   = true
  enable_dns_hostnames = true

  tags = {
    Terraform   = "true"
    Environment = "prod"
  }
}

resource "aws_efs_file_system" "wordpress" {
  creation_token = "wordpress-efs"
  encrypted      = true

  tags = {
    Name = "WordPressContent"
  }
}

resource "aws_efs_mount_target" "mount_targets" {
  count           = length(module.vpc.private_subnets)
  file_system_id  = aws_efs_file_system.wordpress.id
  subnet_id       = module.vpc.private_subnets[count.index]
  security_groups = [aws_security_group.efs.id]
}

resource "aws_db_subnet_group" "wordpress" {
  name       = "wordpress-db-subnet-group"
  subnet_ids = module.vpc.private_subnets

  tags = {
    Name = "WordPress DB Subnet Group"
  }
}

resource "aws_security_group" "rds" {
  name        = "wordpress-rds-sg"
  description = "Allow MySQL access from EC2 instances"
  vpc_id      = module.vpc.vpc_id

  ingress {
    from_port   = 3306
    to_port     = 3306
    protocol    = "tcp"
    security_groups = [aws_security_group.ec2.id]
  }

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }
}

resource "aws_db_instance" "wordpress" {
  identifier             = "wordpressdb"
  engine                 = "mysql"
  engine_version         = "5.7"
  instance_class         = "db.t3.micro"
  allocated_storage      = 20
  storage_encrypted      = true
  username               = "admin"
  password               = random_password.db_password.result
  db_subnet_group_name   = aws_db_subnet_group.wordpress.name
  vpc_security_group_ids = [aws_security_group.rds.id]
  multi_az               = true
  skip_final_snapshot    = true
}

resource "aws_lb" "wordpress" {
  name               = "wordpress-alb"
  internal           = false
  load_balancer_type = "application"
  security_groups    = [aws_security_group.alb.id]
  subnets            = module.vpc.public_subnets

  enable_deletion_protection = false
}

resource "aws_lb_listener" "front_end" {
  load_balancer_arn = aws_lb.wordpress.arn
  port              = 80
  protocol          = "HTTP"

  default_action {
    type             = "forward"
    target_group_arn = aws_lb_target_group.wordpress.arn
  }
}

resource "aws_launch_template" "wordpress" {
  name_prefix   = "wordpress-lt"
  image_id      = data.aws_ami.amazon_linux.id
  instance_type = "t3.micro"
  key_name      = aws_key_pair.ssh.key_name

  iam_instance_profile {
    name = aws_iam_instance_profile.ec2.name
  }

  network_interfaces {
    associate_public_ip_address = false
    security_groups             = [aws_security_group.ec2.id]
  }

  user_data = base64encode(templatefile("userdata.tpl", {
    efs_id      = aws_efs_file_system.wordpress.id
    db_endpoint = aws_db_instance.wordpress.endpoint
    db_name     = "wordpress"
    db_user     = aws_db_instance.wordpress.username
    db_password = aws_db_instance.wordpress.password
  }))
}

resource "aws_autoscaling_group" "wordpress" {
  name                = "wordpress-asg"
  min_size            = 2
  max_size            = 6
  desired_capacity    = 2
  health_check_type   = "ELB"
  vpc_zone_identifier = module.vpc.private_subnets

  launch_template {
    id      = aws_launch_template.wordpress.id
    version = "$Latest"
  }

  target_group_arns = [aws_lb_target_group.wordpress.arn]
}
resource "aws_lb_target_group" "wordpress" {
  name     = "wordpress-tg"
  port     = 80
  protocol = "HTTP"
  vpc_id   = module.vpc.vpc_id

  health_check {
    path                = "/"
    interval            = 30
    timeout             = 5
    healthy_threshold   = 2
    unhealthy_threshold = 2
    matcher             = "200-399"
  }
}

resource "aws_key_pair" "ssh" {
  key_name   = "wordpress-key"
  public_key = var.ssh_public_key
}