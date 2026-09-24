# ============================================================
# Variables — todo-service Terraform Module
# ============================================================

variable "environment" {
  description = "Deployment environment (dev, staging, prod)"
  type        = string

  validation {
    condition     = contains(["dev", "staging", "prod"], var.environment)
    error_message = "environment must be one of: dev, staging, prod"
  }
}

variable "vpc_id" {
  description = "ID of an existing VPC to deploy into when create_networking=false"
  type        = string
  default     = null
  nullable    = true
}

variable "create_networking" {
  description = "Whether to create VPC, subnets, and routing resources in this module"
  type        = bool
  default     = true
}

variable "vpc_cidr" {
  description = "CIDR block for the VPC when create_networking=true"
  type        = string
  default     = "10.42.0.0/16"

  validation {
    condition     = can(cidrhost(var.vpc_cidr, 0))
    error_message = "vpc_cidr must be a valid IPv4 CIDR block."
  }
}

variable "subnet_count" {
  description = "Number of public/private subnets to create when create_networking=true"
  type        = number
  default     = 2

  validation {
    condition     = var.subnet_count >= 2
    error_message = "subnet_count must be at least 2 for ALB high availability."
  }
}

variable "private_subnet_ids" {
  description = "List of private subnet IDs for ECS tasks when create_networking=false"
  type        = list(string)
  default     = []
}

variable "public_subnet_ids" {
  description = "List of public subnet IDs for the ALB when create_networking=false"
  type        = list(string)
  default     = []
}

variable "backend_image" {
  description = "Docker image URI for the backend container (e.g., 123456789.dkr.ecr.us-east-1.amazonaws.com/todo-service-backend:latest)"
  type        = string
  default     = ""
}

variable "frontend_image" {
  description = "Docker image URI for the frontend nginx container (e.g., 123456789.dkr.ecr.us-east-1.amazonaws.com/todo-service-frontend:latest)"
  type        = string
  default     = ""
}

variable "desired_count" {
  description = "Number of ECS task instances to run"
  type        = number
  default     = 1

  validation {
    condition     = var.desired_count >= 1
    error_message = "desired_count must be at least 1"
  }
}

variable "cpu" {
  description = "Fargate task CPU units (256, 512, 1024, 2048, 4096)"
  type        = number
  default     = 256

  validation {
    condition     = contains([256, 512, 1024, 2048, 4096], var.cpu)
    error_message = "cpu must be one of: 256, 512, 1024, 2048, 4096."
  }
}

variable "memory" {
  description = "Fargate task memory in MiB"
  type        = number
  default     = 512

  validation {
    condition     = var.memory >= 512
    error_message = "memory must be at least 512 MiB."
  }
}

variable "frontend_container_port" {
  description = "Container port exposed by the frontend container. Must match the port the nginx image listens on (default: 80)."
  type        = number
  default     = 80

  validation {
    condition     = var.frontend_container_port >= 1 && var.frontend_container_port <= 65535
    error_message = "frontend_container_port must be a valid TCP port (1–65535)."
  }
}

variable "backend_container_port" {
  description = "Container port exposed by the backend container. Must match the port the API image listens on (default: 4000)."
  type        = number
  default     = 4000

  validation {
    condition     = var.backend_container_port >= 1 && var.backend_container_port <= 65535
    error_message = "backend_container_port must be a valid TCP port (1–65535)."
  }
}

variable "log_retention_in_days" {
  description = "CloudWatch log retention period for ECS container logs"
  type        = number
  default     = 30

  validation {
    condition     = contains([1, 3, 5, 7, 14, 30, 60, 90, 120, 150, 180, 365, 400, 545, 731, 1827, 3653], var.log_retention_in_days)
    error_message = "log_retention_in_days must be a valid CloudWatch retention value."
  }
}

variable "alb_ingress_cidr" {
  description = "CIDR block allowed to reach the ALB listener. Must be a specific network range — 0.0.0.0/0 is not permitted in the Slalom Innovation Labs account."
  type        = string

  validation {
    condition     = can(cidrhost(var.alb_ingress_cidr, 0))
    error_message = "alb_ingress_cidr must be a valid IPv4 CIDR block."
  }

  validation {
    condition     = var.alb_ingress_cidr != "0.0.0.0/0"
    error_message = "alb_ingress_cidr cannot be 0.0.0.0/0. Open internet access is not permitted in the Slalom Innovation Labs account. Provide a specific network CIDR (e.g. your office or VPN range)."
  }
}

variable "ecr_force_delete" {
  description = "Force-delete ECR repositories and all contained images on terraform destroy. Set to true only in non-production environments."
  type        = bool
  default     = false
}

variable "alb_deletion_protection_enabled" {
  description = "Whether ALB deletion protection is enabled"
  type        = bool
  default     = false
}
