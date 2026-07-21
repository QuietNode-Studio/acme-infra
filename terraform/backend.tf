terraform {
  backend "s3" {
    bucket       = "acme-tfstate-488179516291" # created by bootstrap/
    key          = "estate/terraform.tfstate"
    region       = "us-east-2"
    use_lockfile = true # native S3 locking — no DynamoDB table to pay for
  }
}
