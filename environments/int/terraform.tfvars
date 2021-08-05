# provider
aws_region = "eu-central-1"

# remote state
aws-int_bucket = "unwoven-state"
aws-int_key    = "aws-int"
aws-int_region = "eu-central-1"
aad-int_bucket = "unwoven-state"
aad-int_key    = "aad-int"
aad-int_region = "eu-central-1"

# context
namespace = "int"
tags = {
  Terraform = "true"
  Namespace = "int"
}
