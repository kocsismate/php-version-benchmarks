terraform {
  required_version = "~>1.5"
  backend "local" {
    path = "./terraform.tfstate"
  }
  required_providers {
    aws = {
      version = "5.0.0"
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

resource "tls_private_key" "ssh_key" {
  algorithm = "RSA"
  rsa_bits  = 4096
}

resource "aws_key_pair" "key_pair" {
  public_key = tls_private_key.ssh_key.public_key_openssh
}

resource "aws_instance" "host" {
  ami = data.aws_ami.host.image_id
  instance_type = var.instance_type
  associate_public_ip_address = true
  key_name = aws_key_pair.key_pair.key_name
  availability_zone = data.aws_availability_zones.available.names[var.availability_zone_index]
  vpc_security_group_ids = [aws_security_group.security_group.id]
  monitoring = true
  tenancy = var.use_dedicated_instance ? "dedicated" : "default"
  instance_initiated_shutdown_behavior = "stop"

  root_block_device {
    volume_type = "io2"
    volume_size = "32"
    iops = 8000
  }

  tags = {
    Name = "php-benchmark-host"
  }

  connection {
    type = "ssh"
    host = aws_instance.host.public_ip
    user = var.image_user
    private_key = tls_private_key.ssh_key.private_key_pem
    timeout = "${var.termination_timeout_in_min}m"
    agent = true
  }

  provisioner "local-exec" {
    command = <<EOF
      set -e

      cd ${var.local_project_root}
      mkdir -p "./tmp/results/${var.result_root_dir}"

      tar --exclude="./build/infrastructure/" -czvf ./tmp/archive.tar.gz ./app/zend/ ./bin ./build ./config ./tmp/results/${var.result_root_dir} .dockerignore Dockerfile
EOF
  }

  provisioner "file" {
    source = "${var.local_project_root}/tmp/archive.tar.gz"
    destination = "/tmp/archive.tar.gz"
  }

  provisioner "remote-exec" {
    inline = [
      "set -e",

      "# Automatic termination",
      "#echo 'sudo halt' | at now + ${var.termination_timeout_in_min} min",

      "# Update permissions",
      "sudo mkdir -p ${var.remote_project_root}",
      "sudo chmod -R 775 ${var.remote_project_root}",
      "sudo chown -R root:${var.image_user} ${var.remote_project_root}",
      "cd ${var.remote_project_root}",

      "# Unzip the archive",
      "tar -xf /tmp/archive.tar.gz",

      "sudo chmod -R 775 ${var.remote_project_root}",
      "sudo chown -R root:${var.image_user} ${var.remote_project_root}",

      "# Update system packages",
      "sudo dnf -y update",
      "sudo dnf -y install git docker",

      "sudo usermod -a -G docker ${var.image_user}" ,
      "sudo service docker start",

      "# Setup environment",
      "export PROJECT_ROOT=\"${var.remote_project_root}\"",
      "export N=\"${var.runs}\"",
      "export RUN=\"${var.run}\"",
      "export NOW=\"${var.now}\"",
      "export RESULT_ROOT_DIR=\"${var.result_root_dir}\"",
      "${var.php_commits}",
      "export INFRA_ID=\"${var.infra_id}\"",
      "export INFRA_NAME=\"${var.infra_name}\"",
      "export INFRA_INSTANCE_TYPE=\"${var.instance_type}\"",
      "export INFRA_ARCHITECTURE=\"${var.image_architecture}\"",
      "export INFRA_ENVIRONMENT=\"${var.environment}\"",
      "export INFRA_RUNNER=\"${var.runner}\"",
      "export INFRA_DOCKER_REGISTRY=\"${var.docker_registry}\"",
      "export INFRA_DOCKER_REPOSITORY=\"${var.docker_repository}\"",

      "# Run the benchmark",
      "${var.remote_project_root}/bin/build.sh $INFRA_ENVIRONMENT",
      "${var.remote_project_root}/bin/setup.sh",

      var.disable_deeper_c_states ? "sudo sed -i 's/rd\\.shell=0\"/rd.shell=0 intel_idle.max_cstate=1\"/' /etc/default/grub && sudo grub2-mkconfig -o /boot/grub2/grub.cfg" : "echo 'skipped disabling deeper C states'",
    ]
  }

  provisioner "remote-exec" {
    inline = [
      "set -e",

      var.disable_deeper_c_states ? "sudo reboot&" : "echo ''"
    ]
    on_failure = continue
  }

  provisioner "remote-exec" {
    inline = [
      "set -e",

      "# Setup environment",
      "export PROJECT_ROOT=\"${var.remote_project_root}\"",
      "export N=\"${var.runs}\"",
      "export RUN=\"${var.run}\"",
      "export NOW=\"${var.now}\"",
      "export RESULT_ROOT_DIR=\"${var.result_root_dir}\"",
      "${var.php_commits}",
      "export INFRA_ID=\"${var.infra_id}\"",
      "export INFRA_NAME=\"${var.infra_name}\"",
      "export INFRA_INSTANCE_TYPE=\"${var.instance_type}\"",
      "export INFRA_ARCHITECTURE=\"${var.image_architecture}\"",
      "export INFRA_ENVIRONMENT=\"${var.environment}\"",
      "export INFRA_RUNNER=\"${var.runner}\"",
      "export INFRA_DOCKER_REGISTRY=\"${var.docker_registry}\"",
      "export INFRA_DOCKER_REPOSITORY=\"${var.docker_repository}\"",

      var.runner == "host" ? "sudo service docker stop" : "echo 'skipped stopping docker service'",
      var.disable_hyper_threading ? "for cpunum in $(cat /sys/devices/system/cpu/cpu*/topology/thread_siblings_list | cut -s -d, -f2- | tr ',' '\n' | sort -un); do echo 0 | sudo tee /sys/devices/system/cpu/cpu$cpunum/online; done" : "echo 'skipped disabling hyper threading'",
      var.disable_turbo_boost ? "sudo sh -c 'echo 1 > /sys/devices/system/cpu/intel_pstate/no_turbo'" : "echo 'skipped disabling turbo boost'",

      "${var.remote_project_root}/bin/benchmark.sh",
    ]
  }

  provisioner "local-exec" {
    command = <<EOP
      set -e

      rm -f "${var.local_project_root}/tmp/archive.tar.gz"

      echo "${tls_private_key.ssh_key.private_key_pem}" > ${var.local_project_root}/tmp/ssh-key.pem
      chmod 600 "${var.local_project_root}/tmp/ssh-key.pem"

      mkdir -p "${var.local_project_root}/tmp/results/${var.result_root_dir}"

      scp -o "IdentitiesOnly=yes" -o ControlPath=none -o StrictHostKeyChecking=no -o UserKnownHostsFile=/dev/null -i "${var.local_project_root}/tmp/ssh-key.pem" -r "${var.image_user}@${aws_instance.host.public_dns}:${var.remote_project_root}/tmp/results/${var.result_root_dir}/*" "${var.local_project_root}/tmp/results/${var.result_root_dir}/"

      rm -f "${var.local_project_root}/tmp/ssh-key.pem"

      if [[ "${var.dry_run}" == "false" ]]; then
        ${var.local_project_root}/bin/generate_results.sh "${var.local_project_root}/tmp/results/${var.result_root_dir}" "${var.local_project_root}/docs/results/${var.result_root_dir}"
      fi
    EOP
  }
}

data "aws_ami" "host" {
  most_recent = true
  owners = ["amazon"]

  filter {
    name   = "name"
    values = ["al2023-ami-minimal-2023*"]
  }

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
