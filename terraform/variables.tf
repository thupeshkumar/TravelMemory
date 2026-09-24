variable "project" {
  description = "Project or stack name used for tagging"
  type        = string
  default     = "mern-stack"
}

variable "region" {
  description = "AWS region"
  type        = string
  default     = "us-east-1"
}

variable "key_name" {
  description = "Existing EC2 key pair name to SSH into instances"
  type        = string
  default     = "Thupesheu"
}

variable "web_instance_type" {
  description = "Instance type for MERN web server"
  type        = string
  default     = "t3.medium"
}

variable "db_instance_type" {
  description = "Instance type for MongoDB server"
  type        = string
  default     = "t3.medium"
}