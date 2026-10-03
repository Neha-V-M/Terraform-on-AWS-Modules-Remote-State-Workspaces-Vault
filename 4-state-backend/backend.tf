# S3 remote backend configuration.
#
# ⚠️ KEEP THIS COMMENTED OUT until after the S3 bucket and DynamoDB table in
# main.tf have actually been created (Phase 1 in the README). Terraform init
# will fail if it points at a backend that doesn't exist yet.
#
# Once the bucket + table exist (Phase 1 apply is done):
#   1. Uncomment the block below
#   2. Replace the bucket value with your real, already-created bucket name
#   3. Run `terraform init` again — Terraform will offer to migrate local
#      state into S3 automatically.

# terraform {
#   backend "s3" {
#     bucket         = "<your-unique-bucket-name>"   # must match aws_s3_bucket.tf_state
#     key            = "terraform/terraform.tfstate"
#     region         = "us-east-1"
#     dynamodb_table = "terraform_lock"               # must match aws_dynamodb_table.tf_lock
#     encrypt        = true
#   }
# }
