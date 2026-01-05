variable "aws_region" {
  description = "AWS region to build the AMI in"
  type        = string
  default     = env("AWS_REGION") != "" ? env("AWS_REGION") : "us-east-1"
}

variable "instance_type" {
  description = "EC2 instance type for building the AMI"
  type        = string
  default     = "t3.micro"
}

variable "ami_name" {
  description = "Name of the resulting AMI"
  type        = string
  default     = "dragon-server"
}

variable "ssh_username" {
  description = "SSH username for connecting to the instance"
  type        = string
  default     = "ubuntu"
}

variable "tags" {
  description = "Tags to apply to the AMI and build resources"
  type        = map(string)
  default = {
    Name    = "dragon-server"
    Project = "dragon-server"
    Builder = "packer"
  }
}
