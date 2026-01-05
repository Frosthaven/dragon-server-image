packer {
  required_plugins {
    amazon = {
      version = ">= 1.0.0"
      source  = "github.com/hashicorp/amazon"
    }
    ansible = {
      version = "~> 1"
      source  = "github.com/hashicorp/ansible"
    }
  }
}

locals {
  timestamp = formatdate("YYYY-MM-DD", timestamp())
}

source "amazon-ebs" "dragon-server" {
  region        = var.aws_region
  instance_type = var.instance_type
  ami_name      = "${var.ami_name}-${local.timestamp}"
  ssh_username  = var.ssh_username

  # Find the latest Ubuntu 24.04 LTS AMI from Canonical
  source_ami_filter {
    filters = {
      name                = "ubuntu/images/hvm-ssd-gp3/ubuntu-noble-24.04-amd64-server-*"
      root-device-type    = "ebs"
      virtualization-type = "hvm"
    }
    owners      = ["099720109477"] # Canonical's AWS account ID
    most_recent = true
  }

  tags = merge(var.tags, {
    Name      = "${var.ami_name}-${local.timestamp}"
    Timestamp = local.timestamp
  })

  run_tags = var.tags
}

build {
  sources = ["source.amazon-ebs.dragon-server"]

  provisioner "ansible" {
    user          = var.ssh_username
    playbook_file = "./playbook.yml"
    extra_arguments = [
      "--scp-extra-args", "'-O'" # Workaround for "failed to transfer" errors
    ]
  }
}
