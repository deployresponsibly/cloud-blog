output "site_url" {
  value = "https://${local.site_fqdn}"
}

output "bucket_name" {
  description = "Upload the built site here: aws s3 sync ../dist s3://<bucket> --delete"
  value       = aws_s3_bucket.site.id
}

output "distribution_id" {
  description = "Use for invalidations: aws cloudfront create-invalidation --distribution-id <id> --paths '/*'"
  value       = aws_cloudfront_distribution.site.id
}

output "subscription_status" {
  value = awscc_pricingplanmanager_subscription.site.status
}

output "deploy_runner_label" {
  description = "runs-on label for the deploy job (the run id/attempt suffix is added in the workflow)"
  value       = "codebuild-${aws_codebuild_project.deploy.name}"
}
