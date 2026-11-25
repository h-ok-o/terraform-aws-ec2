# ---------------------------------------------------------------
# Pile web NovaSphere : SG, Launch Template, ALB, target group,
# listener, ASG. Aucun bloc provider ici : il vit dans envs/*.
# ---------------------------------------------------------------

locals {
  name = "novasphere-${var.environment}"
}

# ---------- Security Groups ----------

resource "aws_security_group" "alb" {
  name_prefix = "${local.name}-alb-"
  description = "ALB : HTTP depuis Internet"
  vpc_id      = var.vpc_id

  tags = { Name = "${local.name}-alb" }

  lifecycle {
    create_before_destroy = true
  }
}

resource "aws_vpc_security_group_ingress_rule" "alb_http" {
  security_group_id = aws_security_group.alb.id
  description       = "HTTP depuis Internet"
  ip_protocol       = "tcp"
  from_port         = 80
  to_port           = 80
  cidr_ipv4         = "0.0.0.0/0"
}

resource "aws_vpc_security_group_egress_rule" "alb_all" {
  security_group_id = aws_security_group.alb.id
  description       = "Sortie libre (vers les instances)"
  ip_protocol       = "-1"
  cidr_ipv4         = "0.0.0.0/0"
}

resource "aws_security_group" "web" {
  name_prefix = "${local.name}-web-"
  description = "Instances : HTTP uniquement depuis ALB, aucun SSH"
  vpc_id      = var.vpc_id

  tags = { Name = "${local.name}-web" }

  lifecycle {
    create_before_destroy = true
  }
}

# Le trafic n'est accepté que depuis le Security Group de l'ALB.
resource "aws_vpc_security_group_ingress_rule" "web_from_alb" {
  security_group_id            = aws_security_group.web.id
  description                  = "HTTP depuis ALB uniquement"
  ip_protocol                  = "tcp"
  from_port                    = 80
  to_port                      = 80
  referenced_security_group_id = aws_security_group.alb.id
}

# Sans NAT Gateway, les instances sortent directement (dnf, SSM).
resource "aws_vpc_security_group_egress_rule" "web_all" {
  security_group_id = aws_security_group.web.id
  description       = "Sortie libre (installation, Parameter Store)"
  ip_protocol       = "-1"
  cidr_ipv4         = "0.0.0.0/0"
}

# ---------- Launch Template ----------

resource "aws_launch_template" "web" {
  name_prefix   = "${local.name}-"
  image_id      = var.ami_id
  instance_type = var.instance_type

  iam_instance_profile {
    name = var.instance_profile_name
  }

  vpc_security_group_ids = [aws_security_group.web.id]

  # IMDSv2 exigé (socle sécurité).
  metadata_options {
    http_endpoint               = "enabled"
    http_tokens                 = "required"
    http_put_response_hop_limit = 1
  }

  # Seul le NOM de l'environnement et le CHEMIN du secret sont passés :
  # ce ne sont pas des secrets.
  user_data = base64encode(templatefile("${path.module}/bootstrap.sh", {
    environment           = var.environment
    secret_parameter_path = var.secret_parameter_path
  }))

  tag_specifications {
    resource_type = "instance"
    tags          = { Name = "${local.name}-web" }
  }

  lifecycle {
    create_before_destroy = true
  }
}

# ---------- ALB, target group, listener ----------

resource "aws_lb" "web" {
  name               = "${local.name}-alb"
  load_balancer_type = "application"
  security_groups    = [aws_security_group.alb.id]
  subnets            = var.subnet_ids
}

resource "aws_lb_target_group" "web" {
  name     = "${local.name}-tg"
  port     = 80
  protocol = "HTTP"
  vpc_id   = var.vpc_id

  health_check {
    path                = "/"
    matcher             = "200"
    interval            = 15
    healthy_threshold   = 2
    unhealthy_threshold = 3
  }
}

resource "aws_lb_listener" "http" {
  load_balancer_arn = aws_lb.web.arn
  port              = 80
  protocol          = "HTTP"

  default_action {
    type             = "forward"
    target_group_arn = aws_lb_target_group.web.arn
  }
}

# TODO extension HTTPS : listener 443 avec certificat ACM importé,
# et redirection 80 -> 443 (à répartir avec l'équipe).

# ---------- Auto Scaling Group ----------

resource "aws_autoscaling_group" "web" {
  name                = "${local.name}-asg"
  min_size            = var.asg_min_size
  max_size            = var.asg_max_size
  desired_capacity    = var.asg_min_size
  vpc_zone_identifier = var.subnet_ids
  target_group_arns   = [aws_lb_target_group.web.arn]

  # L'ASG remplace une instance si l'ALB la juge en échec.
  health_check_type         = "ELB"
  health_check_grace_period = 120

  launch_template {
    id      = aws_launch_template.web.id
    version = aws_launch_template.web.latest_version
  }

  instance_refresh {
    strategy = "Rolling"
    preferences {
      min_healthy_percentage = 50
    }
  }
}
