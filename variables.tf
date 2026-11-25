variable "environment" {
  description = "Nom de l'environnement (dev ou prod)."
  type        = string

  validation {
    condition     = contains(["dev", "prod"], var.environment)
    error_message = "environment doit valoir \"dev\" ou \"prod\"."
  }
}

variable "vpc_id" {
  description = "ID du VPC dans lequel déployer la pile web."
  type        = string
}

variable "subnet_ids" {
  description = "Sous-réseaux publics (au moins 2, sur deux zones) pour l'ALB et l'ASG."
  type        = list(string)

  validation {
    condition     = length(var.subnet_ids) >= 2
    error_message = "Il faut au moins deux sous-réseaux (deux zones de disponibilité)."
  }
}

variable "ami_id" {
  description = "AMI Amazon Linux 2023 (variante standard, avec l'agent SSM)."
  type        = string
}

variable "instance_type" {
  description = "Type d'instance EC2."
  type        = string
  default     = "t3.micro"
}

variable "instance_profile_name" {
  description = "Profil d'instance IAM (LabInstanceProfile dans le Learner Lab)."
  type        = string
}

variable "secret_parameter_path" {
  description = "Chemin Parameter Store du secret de l'environnement, ex. /novasphere/dev/calendar-api-key. Ce n'est pas un secret."
  type        = string
}

variable "asg_min_size" {
  description = "Nombre minimum d'instances (socle : 2)."
  type        = number
  default     = 2

  validation {
    condition     = var.asg_min_size >= 2
    error_message = "Le socle impose au moins 2 instances."
  }
}

variable "asg_max_size" {
  description = "Nombre maximum d'instances."
  type        = number
  default     = 3
}
