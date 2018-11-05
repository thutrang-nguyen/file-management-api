variable "aws_access_key" {
  type = "string"
  description = "Access Key to provision"
}

variable "aws_secret_key" {
  type = "string"
  description = "Secret Key to provision"
}

variable "aws_region" {
  type = "string"
  description = "Region to provision"
  default = "ap-southeast-1"
}

variable "aws_dynamodb_table_name" {
  type = "string"
  description = "DynamoDB Table name"
  default = "File"
}

variable "aws_s3_bucket_name_prefix" {
  type = "string"
  description = "S3 bucket name prefix"
  default = "file-content-"
}

variable "fargate_cpu" {
  type = "string"
  description = "CPU limit of Fargate instance"
  default = "256"
}

variable "fargate_memory" {
  type = "string"
  description = "Memory limit of Fargate instance"
  default = "512"
}

variable "app_port" {
  type = "string"
  description = "Exposed port of Fargate instance"
  default = "5000"
}

variable "app_count" {
  type = "string"
  description = "Number of replica of Fargate instance"
  default = "1"
}