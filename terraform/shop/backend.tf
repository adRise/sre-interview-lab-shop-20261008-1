terraform {
  backend "s3" {
    bucket       = "sre-interview-lab-tfstate-490233488193"
    key          = "shop/terraform.tfstate"
    region       = "us-east-2"
    encrypt      = true
    use_lockfile = true
  }
}
