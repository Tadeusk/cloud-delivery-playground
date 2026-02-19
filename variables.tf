variable "vpc_cidr" {
  description = "Zakres IP dla naszego VPC"
  type        = string
  default     = "10.0.0.0/16"
}

variable "project_name" {
  description = "Nazwa projektu do tagowania"
  type        = string
  default     = "Krzysiu-Cloud-Project"
}