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

resource "aws_instance" "ec2_instance" {
  ami = data.aws_ami.ubuntu.image_id
  instance_type = var.instance_type
  associate_public_ip_address = true
  key_name = var.ssh_key_name
  vpc_security_group_ids = [aws_security_group.security_group.id]
  monitoring = false
  host_id = var.dedicated_host_id

  tags = {
    Name = "php-benchmark"
  }

  connection {
    type = "ssh"
    host = aws_instance.ec2_instance.public_ip
    user = "ubuntu"
    private_key = file(format("%s/%s", "../config", var.ssh_private_key))
    timeout = "30m"
    agent = true
  }

  provisioner "local-exec" {
    command = <<EOF
      set -e

      cd ${var.project_root}
      tar --exclude="./build/infrastructure/" -czvf ./tmp/archive.tar.gz ./app/zend/opcache.php ./app/zend/phpinfo.php ./bin ./build ./config .dockerignore .env.dist Dockerfile
EOF
  }

  provisioner "file" {
    source = "${var.project_root}/tmp/archive.tar.gz"
    destination = "/home/ubuntu/archive.tar.gz"
  }

  provisioner "remote-exec" {
    inline = [
      "set -e",

      "# Update permissions",
      "sudo mkdir -p /php-benchmark",
      "sudo chmod -R 775 /php-benchmark",
      "sudo chown -R root:ubuntu /php-benchmark",
      "cd /php-benchmark",

      "# Unzip the archive",
      "tar -xf /home/ubuntu/archive.tar.gz",

      "# Create and source the config file",
      "cp .env.dist .env",

      "sudo chmod -R 775 /php-benchmark",
      "sudo chown -R root:ubuntu /php-benchmark",
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

data "aws_ami" "ubuntu" {
  most_recent = true
  owners = ["099720109477"]

  filter {
    name = "virtualization-type"
    values = ["hvm"]
  }

  filter {
    name = "architecture"
    values = [var.image_architecture]
  }

  filter {
    name = "image-type"
    values = ["machine"]
  }

  filter {
    name = "name"
    values = ["ubuntu/images/hvm-ssd/${var.image_name}-*"]
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
