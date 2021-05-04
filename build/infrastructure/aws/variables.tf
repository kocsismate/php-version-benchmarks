variable "access_key" {
  type = string
  sensitive = true
}

variable "secret_key" {
  type = string
  sensitive = true
}

variable "ssh_key_name" {
  type = string
}

variable "ssh_private_key" {
  type = string
  sensitive = true
}

variable "region" {
  type = string
}


variable "run" {
  type = number
}

variable "runs" {
  type = number
}

variable "now" {
  type = string
}

variable "result_root_dir" {
  type = string
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

variable "image_owner" {
  type = string
}

variable "image_name_pattern" {
  type = string
}

variable "image_architecture" {
  type = string
}

variable "image_user" {
  type = string
}

variable "dedicated_host_id" {
  type = string
}

variable "use_dedicated_host" {
  type = bool
}

variable "disable_turbo_boost" {
  type = bool
}

variable "infra_name" {
  type = string
}

variable "environment" {
  type = string
}

variable "provisioner" {
  type = string
}

variable "docker_registry" {
  type = string
}

variable "docker_repository" {
  type = string
}
