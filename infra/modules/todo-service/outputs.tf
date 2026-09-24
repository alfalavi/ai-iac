output "service_url" {
  description = "DNS name of the Application Load Balancer"
  value       = "http://${aws_lb.todo_service.dns_name}"
}

output "frontend_url" {
  description = "Public frontend URL"
  value       = "http://${aws_lb.todo_service.dns_name}/"
}

output "api_base_url" {
  description = "Public API base URL exposed through nginx"
  value       = "http://${aws_lb.todo_service.dns_name}/api"
}

output "cluster_name" {
  description = "Name of the ECS cluster"
  value       = aws_ecs_cluster.todo_service.name
}

output "cluster_arn" {
  description = "ARN of the ECS cluster"
  value       = aws_ecs_cluster.todo_service.arn
}

output "service_name" {
  description = "Name of the ECS service"
  value       = aws_ecs_service.todo_service.name
}

output "alb_arn" {
  description = "ARN of the Application Load Balancer"
  value       = aws_lb.todo_service.arn
}

output "alb_security_group_id" {
  description = "Security group attached to the ALB"
  value       = aws_security_group.alb.id
}

output "backend_ecr_repository_url" {
  description = "URL of the backend ECR repository"
  value       = aws_ecr_repository.backend.repository_url
}

output "frontend_ecr_repository_url" {
  description = "URL of the frontend ECR repository"
  value       = aws_ecr_repository.frontend.repository_url
}

output "vpc_id" {
  description = "VPC ID used by the service"
  value       = local.effective_vpc_id
}

output "public_subnet_ids" {
  description = "Public subnet IDs used by the ALB"
  value       = local.effective_public_subnet_ids
}

output "private_subnet_ids" {
  description = "Private subnet IDs used by ECS tasks"
  value       = local.effective_private_subnet_ids
}

output "task_role_arn" {
  description = "ARN of the ECS task IAM role. Attach additional policies here to grant the application AWS permissions."
  value       = aws_iam_role.ecs_task.arn
}

output "task_role_name" {
  description = "Name of the ECS task IAM role. Use this to attach inline or managed policies from a parent module."
  value       = aws_iam_role.ecs_task.name
}

output "execution_role_arn" {
  description = "ARN of the ECS task execution IAM role used by the ECS agent to pull images and write logs."
  value       = aws_iam_role.ecs_task_execution.arn
}

output "ecs_tasks_security_group_id" {
  description = "ID of the security group attached to ECS tasks. Add ingress rules to allow additional intra-service traffic."
  value       = aws_security_group.ecs_tasks.id
}
