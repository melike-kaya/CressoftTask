# Variables
variable "name"         { type = string }           # örn: dockyard
variable "env"          { type = string }           # dev | prod
variable "region"       { type = string }
variable "ecr_registry" { type = string }           # 123456789012.dkr.ecr.us-east-1.amazonaws.com
variable "ecr_repo"     { type = string }           # demo-app-repo
variable "memory_mb"    { type = number default = 256 }
variable "timeout_s"    { type = number default = 10 }
