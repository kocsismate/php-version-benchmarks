variable "access_key" {
  type = string
  sensitive = true
}

variable "secret_key" {
  type = string
  sensitive = true
}

variable "region" {
  type = string
}

variable "availability_zone_index" {
  type = number
}

variable "run" {
  type = number
}

variable "runs" {
  type = number
}

variable "dry_run" {
  type = bool
}

variable "now" {
  type = string
}

variable "result_root_dir" {
  type = string
}

variable "tags" {
  description = "Custom tags on AWS resources"
  type        = map(string)

  default = {
    "Name" = "php-version-benchmark"
  }
}

variable "scheduler_tag" {
  description = "Identifies AWS resources to stop"
  type        = map(string)

  default = {
    "key"   = "to_stop"
    "value" = "true"
  }
}

variable "termination_timeout_in_min" {
  type = number
}

variable "remote_project_root" {
  type = string
}

variable "local_project_root" {
  type = string
}

variable "php_commits" {
  type = string
}

variable "instance_type" {
  type = string
}

variable "image_architecture" {
  type = string
}

variable "image_user" {
  type = string
}

variable "use_dedicated_instance" {
  type = bool
}

variable "disable_hyper_threading" {
  type = bool
}

variable "disable_deeper_c_states" {
  type = bool
}

variable "disable_turbo_boost" {
  type = bool
}

variable "lock_cpu_frequency" {
  type = bool
}

variable "infra_id" {
  type = string
}

variable "infra_name" {
  type = string
}

variable "environment" {
  type = string
}

variable "runner" {
  type = string
}

variable "measure_instruction_count" {
  type = string
}

variable "docker_registry" {
  type = string
  sensitive = false
}

variable "docker_repository" {
  type = string
}

variable "github_token" {
  type = string
  sensitive = false
}

variable "log_url" {
  type = string
  sensitive = false
}

variable "artifact_url" {
  type = string
  sensitive = false
}

variable "extra_title" {
  type = string
  sensitive = false
}

variable "extra_text" {
  type = string
  sensitive = false
}
