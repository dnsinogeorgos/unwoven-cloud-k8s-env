variable "name" {
  type = string
}

variable "namespace" {
  type = string
}

variable "users" {
  type = set(string)
}
