# ---------------------------------------------------------------------------
# Deploy pipeline: a CodeBuild-hosted GitHub Actions runner (Lambda compute).
#
# GitHub-hosted runners build dist/ and upload it as an artifact; only the
# deploy job runs here, so the one place that holds AWS credentials never
# executes npm. The job runs under aws_iam_role.deploy below, which can touch
# this site's bucket and distribution and nothing else.
#
# Apply in two steps: the GitHub connection is created PENDING and must be
# authorized once in the console before the project and webhook can use it.
#   terraform apply -target=aws_codeconnections_connection.github
#   (console: Developer Tools > Settings > Connections > Update pending connection)
#   terraform apply
# ---------------------------------------------------------------------------

locals {
  deploy_project_name = "cloud-blog-deploy"
  deploy_project_arn  = "arn:aws:codebuild:us-east-1:${data.aws_caller_identity.current.account_id}:project/${local.deploy_project_name}"
}

resource "aws_codeconnections_connection" "github" {
  name          = "deployresponsibly"
  provider_type = "GitHub"
}

resource "aws_cloudwatch_log_group" "deploy" {
  name              = "/aws/codebuild/${local.deploy_project_name}"
  retention_in_days = 30
}

resource "aws_iam_role" "deploy" {
  name = local.deploy_project_name

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Effect    = "Allow"
      Principal = { Service = "codebuild.amazonaws.com" }
      Action    = "sts:AssumeRole"
      Condition = {
        StringEquals = {
          "aws:SourceAccount" = data.aws_caller_identity.current.account_id
          "aws:SourceArn"     = local.deploy_project_arn
        }
      }
    }]
  })
}

resource "aws_iam_role_policy" "deploy" {
  name = "deploy-site"
  role = aws_iam_role.deploy.id

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Sid      = "ListSiteBucket"
        Effect   = "Allow"
        Action   = "s3:ListBucket"
        Resource = aws_s3_bucket.site.arn
      },
      {
        Sid      = "WriteSiteObjects"
        Effect   = "Allow"
        Action   = ["s3:PutObject", "s3:DeleteObject"]
        Resource = "${aws_s3_bucket.site.arn}/*"
      },
      {
        Sid      = "InvalidateSiteCache"
        Effect   = "Allow"
        Action   = "cloudfront:CreateInvalidation"
        Resource = aws_cloudfront_distribution.site.arn
      },
      {
        Sid    = "RunnerGitHubConnection"
        Effect = "Allow"
        Action = [
          "codeconnections:GetConnection",
          "codeconnections:GetConnectionToken",
          "codeconnections:UseConnection",
        ]
        Resource = aws_codeconnections_connection.github.arn
      },
      {
        Sid      = "WriteLogs"
        Effect   = "Allow"
        Action   = ["logs:CreateLogStream", "logs:PutLogEvents"]
        Resource = "${aws_cloudwatch_log_group.deploy.arn}:*"
      },
    ]
  })
}

resource "aws_codebuild_project" "deploy" {
  name         = local.deploy_project_name
  description  = "GitHub Actions runner for the ${local.site_fqdn} deploy job"
  service_role = aws_iam_role.deploy.arn

  artifacts {
    type = "NO_ARTIFACTS"
  }

  # Lambda compute is covered by the CodeBuild free tier (6,000 s/month at 1 GB).
  # It cannot run Docker or write outside /tmp, which this job does not need.
  environment {
    type         = "LINUX_LAMBDA_CONTAINER"
    compute_type = "BUILD_LAMBDA_1GB"
    image        = "aws/codebuild/amazonlinux-x86_64-lambda-standard:nodejs20"
  }

  source {
    type     = "GITHUB"
    location = "https://github.com/${var.github_repo}.git"

    auth {
      type     = "CODECONNECTIONS"
      resource = aws_codeconnections_connection.github.arn
    }
  }

  logs_config {
    cloudwatch_logs {
      group_name = aws_cloudwatch_log_group.deploy.name
    }
  }

  depends_on = [aws_iam_role_policy.deploy]
}

# Only jobs from the "Deploy" workflow are picked up by this runner.
resource "aws_codebuild_webhook" "deploy" {
  project_name = aws_codebuild_project.deploy.name
  build_type   = "BUILD"

  filter_group {
    filter {
      type    = "EVENT"
      pattern = "WORKFLOW_JOB_QUEUED"
    }

    filter {
      type    = "WORKFLOW_NAME"
      pattern = "^Deploy$"
    }
  }
}
