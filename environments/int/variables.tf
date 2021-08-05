# provider
variable "aws_region" {
  type = string
}

# remote state
variable "aws-int_bucket" {
  type = string
}

variable "aws-int_key" {
  type = string
}

variable "aws-int_region" {
  type = string
}

variable "aad-int_bucket" {
  type = string
}

variable "aad-int_key" {
  type = string
}

variable "aad-int_region" {
  type = string
}
