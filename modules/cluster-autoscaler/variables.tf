variable "aws_region" {
  type = string
}

variable "cluster_id" {
  type = string
}

variable "node_groups" {
  type = list(map(any))
}
