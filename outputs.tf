output "alb_dns_name" {
  description = "Nom DNS de l'ALB."
  value       = aws_lb.web.dns_name
}

output "target_group_arn" {
  description = "ARN du target group."
  value       = aws_lb_target_group.web.arn
}

output "asg_name" {
  description = "Nom de l'Auto Scaling Group."
  value       = aws_autoscaling_group.web.name
}
