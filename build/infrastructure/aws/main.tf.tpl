terraform {
  required_version = "~>0.15.0"
  backend "local" {
    path = "./terraform.tfstate"
  }
  required_providers {
    aws = {
      version = "~>3.37"
    }
  }
}

provider "aws" {
  region = var.region
  access_key = var.access_key
  secret_key = var.secret_key
}

data "aws_availability_zones" "available" {
  state = "available"
}

data "template_file" "user_data" {
  template = file("./cloud_data.yaml")
}

resource "aws_instance" "client" {
  ami = data.aws_ami.client.image_id
  instance_type = var.client_instance_type
  associate_public_ip_address = true
  key_name = var.ssh_key_name
  availability_zone = data.aws_availability_zones.available.names[0]
  vpc_security_group_ids = [aws_security_group.security_group.id]
  monitoring = true
  host_id = var.dedicated_host_id
  user_data = data.template_file.user_data.rendered

  root_block_device {
    volume_type = "gp2"
    volume_size = "32"
  }

  tags = {
    Name = "php-benchmark-client"
  }

  connection {
    type = "ssh"
    host = aws_instance.client.public_ip
    user = var.client_ssh_user
    private_key = file(format("%s/%s", "../config", var.ssh_private_key))
    timeout = "30m"
    agent = true
  }

  provisioner "local-exec" {
    command = <<EOF
      set -e

      cd ${var.project_root}
      tar --exclude="./build/infrastructure/" -czvf ./tmp/archive.tar.gz ./app/zend/ ./bin ./build ./config .dockerignore .env.dist Dockerfile
EOF
  }

  provisioner "file" {
    source = "${var.project_root}/tmp/archive.tar.gz"
    destination = "/home/${var.client_ssh_user}/archive.tar.gz"
  }

  provisioner "remote-exec" {
    inline = [
      "set -e",

      "# Update permissions",
      "sudo mkdir -p /php-benchmark",
      "sudo chmod -R 775 /php-benchmark",
      "sudo chown -R root:${var.client_ssh_user} /php-benchmark",
      "cd /php-benchmark",

      "# Unzip the archive",
      "tar -xf ~/archive.tar.gz",

      "# Create and source the config file",
      "cp .env.dist .env",

      "sudo chmod -R 775 /php-benchmark",
      "sudo chown -R root:${var.client_ssh_user} /php-benchmark",
    ]
  }

  provisioner "remote-exec" {
    inline = [
      "set -e",

      "# Update system packages",
      "sudo apt-get update",
      "sudo apt-get -y install git curl",

      "# Install Docker",
      "curl -fsSL https://get.docker.com/ | sh",

      "# Setup apps",
      "export PROJECT_ROOT=/php-benchmark",
      "/php-benchmark/bin/setup.sh aws-docker",
    ]
  }$PROVISIONERS
}

data "aws_ami" "client" {
  most_recent = true
  owners = [var.client_image_owner]

  filter {
    name = "virtualization-type"
    values = ["hvm"]
  }

  filter {
    name = "architecture"
    values = [var.client_image_architecture]
  }

  filter {
    name = "image-type"
    values = ["machine"]
  }

  filter {
    name = "name"
    values = [var.client_image_name_pattern]
  }
}

resource "aws_security_group" "security_group" {
  name = "php-version-benchmark"

  egress {
    from_port = 0
    to_port = 0
    protocol = "-1"
    cidr_blocks = [
      "0.0.0.0/0"]
  }

  ingress {
    from_port = 0
    to_port = 0
    protocol = "-1"

    cidr_blocks = [
      "0.0.0.0/0"]
  }
}
