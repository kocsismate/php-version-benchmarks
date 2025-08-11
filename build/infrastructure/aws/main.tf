terraform {
  required_version = "~>1.5"
  backend "local" {
    path = "./terraform.tfstate"
  }
  required_providers {
    aws = {
      version = "5.65.0"
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

  tags = merge(var.tags, {(var.scheduler_tag["key"]) = var.scheduler_tag["value"]})

  connection {
    type = "ssh"
    host = aws_instance.host.public_ip
    user = var.image_user
    private_key = tls_private_key.ssh_key.private_key_pem
    timeout = "${var.termination_timeout_in_min}m"
    agent = false
  }

  provisioner "local-exec" {
    command = <<EOF
      set -e

      cd ${var.local_project_root}
      mkdir -p "./tmp/results/${var.result_root_dir}"

      tar --exclude="./build/infrastructure/" -czvf ./tmp/archive.tar.gz ./app/Dockerfile ./app/zend/ ./app/laravel.composer.lock/ ./bin ./build ./config ./tmp/results/${var.result_root_dir}
EOF
  }

  provisioner "file" {
    source = "${var.local_project_root}/tmp/archive.tar.gz"
    destination = "/tmp/archive.tar.gz"
  }

  provisioner "remote-exec" {
    inline = [
      "set -e",

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
      "export INFRA_MEASURE_INSTRUCTION_COUNT=\"${var.measure_instruction_count}\"",
      "export INFRA_DOCKER_REGISTRY=\"${var.docker_registry}\"",
      "export INFRA_DOCKER_REPOSITORY=\"${var.docker_repository}\"",
      "export GITHUB_TOKEN=\"${var.github_token}\"",

      "# Setup the benchmark",
      "${var.remote_project_root}/bin/build.sh $INFRA_ENVIRONMENT",
      "${var.remote_project_root}/bin/setup.sh",

      var.disable_deeper_c_states ? "sudo sed -i 's/quiet\"/quiet intel_idle.max_cstate=1 processor.max_cstate=1\"/' /etc/default/grub && sudo grub2-mkconfig -o /boot/grub2/grub.cfg" : "echo 'skipped disabling deeper C states'",
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
      "export INFRA_DEDICATED_INSTANCE=\"${var.use_dedicated_instance ? 1 : 0}\"",
      "export INFRA_DISABLE_DEEPER_C_STATES=\"${var.disable_deeper_c_states ? 1 : 0}\"",
      "export INFRA_DISABLE_TURBO_BOOST=\"${var.disable_turbo_boost ? 1 : 0}\"",
      "export INFRA_DISABLE_HYPER_THREADING=\"${var.disable_hyper_threading ? 1 : 0}\"",
      "export INFRA_ENVIRONMENT=\"${var.environment}\"",
      "export INFRA_RUNNER=\"${var.runner}\"",
      "export INFRA_MEASURE_INSTRUCTION_COUNT=\"${var.measure_instruction_count}\"",
      "export INFRA_DOCKER_REGISTRY=\"${var.docker_registry}\"",
      "export INFRA_DOCKER_REPOSITORY=\"${var.docker_repository}\"",
      "export GITHUB_TOKEN=\"${var.github_token}\"",

      "${var.remote_project_root}/build/script/system_settings.sh",
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
        ${var.local_project_root}/bin/generate_results.sh "${var.local_project_root}/tmp/results/${var.result_root_dir}" "${var.local_project_root}/docs/results/${var.result_root_dir}" "${var.now}"
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

################################################
#
#            AUTOMATIC TERMINATION
#
################################################

resource "aws_iam_role" "this" {
  name               = "php-version-benchmark-termination-scheduler-lambda"
  description        = "Allows Lambda functions to stop and start ec2 and rds resources"
  assume_role_policy = data.aws_iam_policy_document.this.json
  tags               = var.tags
}

data "aws_iam_policy_document" "this" {
  statement {
    actions = ["sts:AssumeRole"]

    principals {
      type        = "Service"
      identifiers = ["lambda.amazonaws.com"]
    }
  }
}

resource "aws_iam_role_policy" "termination_lambda" {
  name   = "php-version-benchmark-termination-lambda-policy"
  role   = aws_iam_role.this.id
  policy = data.aws_iam_policy_document.termination_lambda.json
}

data "aws_iam_policy_document" "termination_lambda" {
  statement {
    actions = [
      "tag:GetResources",
      "ec2:StopInstances",
      "ec2:StartInstances",
      "autoscaling:DescribeAutoScalingInstances",
    ]

    resources = [
      "*",
    ]
  }
}

resource "aws_iam_role_policy" "termination_lambda_cloudwatch_alarm" {
  name   = "php-version-benchmark-termination-cloudwatch-custom-policy-scheduler"
  role   = aws_iam_role.this.id
  policy = data.aws_iam_policy_document.termination_lambda_cloudwatch_alarm.json
}

data "aws_iam_policy_document" "termination_lambda_cloudwatch_alarm" {
  statement {
    actions = [
      "cloudwatch:DisableAlarmActions",
      "cloudwatch:EnableAlarmActions",
    ]

    resources = [
      "*",
    ]
  }
}

resource "aws_iam_role_policy" "lambda_logging" {
  name   = "php-version-benchmark-termination-lambda-logging"
  role   = aws_iam_role.this.id
  policy = jsonencode({
    "Version" : "2012-10-17",
    "Statement" : [
      {
        "Action" : [
          "logs:CreateLogStream",
          "logs:PutLogEvents"
        ],
        "Resource" : "${aws_cloudwatch_log_group.this.arn}:*",
        "Effect" : "Allow"
      }
    ]
  })
}

# Convert *.py to .zip because AWS Lambda needs .zip
data "archive_file" "package" {
  type        = "zip"
  source_dir  = "${var.local_project_root}/build/infrastructure/package/"
  output_path = "${var.local_project_root}/tmp/aws-stop-start-resources.zip"
}

# Create Lambda function for stop or start aws resources
resource "aws_lambda_function" "this" {
  filename         = data.archive_file.package.output_path
  source_code_hash = data.archive_file.package.output_base64sha256
  function_name    = "php-version-benchmark-termination-lambda-function"
  role             = aws_iam_role.this.arn
  handler          = "scheduler.main.lambda_handler"
  runtime          = "python3.10"
  timeout          = "600"
  kms_key_arn      = ""

  environment {
    variables = {
      AWS_REGIONS                     = var.region
      SCHEDULE_ACTION                 = "stop"
      TAG_KEY                         = var.scheduler_tag["key"]
      TAG_VALUE                       = var.scheduler_tag["value"]
      EC2_SCHEDULE                    = "true"
    }
  }

  tags = var.tags
}

locals {
  rfc_3339_now = "${replace(var.now, " ", "T")}Z"
  termination_time = timeadd(local.rfc_3339_now, "${var.termination_timeout_in_min}m")
  termination_hour = formatdate("h", local.termination_time)
  termination_minute = formatdate("m", local.termination_time)
  termination_day = formatdate("D", local.termination_time)
  termination_month = formatdate("M", local.termination_time)
  termination_year = formatdate("YYYY", local.termination_time)
  cloudwatch_schedule_expression = "cron(${local.termination_minute} ${local.termination_hour} ${local.termination_day} ${local.termination_month} ? ${local.termination_year})"
}

resource "aws_cloudwatch_event_rule" "this" {
  name                = "php-version-benchmark-termination-lambda-scheduler"
  description         = "Trigger lambda scheduler"
  schedule_expression = local.cloudwatch_schedule_expression
  tags                = var.tags
}

resource "aws_cloudwatch_event_target" "this" {
  arn  = aws_lambda_function.this.arn
  rule = aws_cloudwatch_event_rule.this.name
}

resource "aws_lambda_permission" "this" {
  statement_id  = "AllowExecutionFromCloudWatch"
  action        = "lambda:InvokeFunction"
  principal     = "events.amazonaws.com"
  function_name = aws_lambda_function.this.function_name
  source_arn    = aws_cloudwatch_event_rule.this.arn
}

resource "aws_cloudwatch_log_group" "this" {
  name              = "/aws/lambda/php-version-benchmark-termination"
  retention_in_days = 7
  tags              = var.tags
}
