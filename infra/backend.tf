# State bucket is created out-of-band (chicken-and-egg), with versioning,
# encryption, public access block and a TLS-only policy.
# The bucket name is not committed. Supply it at init time:
#   terraform init -backend-config=backend.hcl
# (see backend.hcl.example). Credentials come from AWS_PROFILE.
terraform {
  backend "s3" {
    key          = "cloud-blog/terraform.tfstate"
    region       = "us-east-1"
    encrypt      = true
    use_lockfile = true
  }
}
