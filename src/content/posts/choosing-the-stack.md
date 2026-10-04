---
title: Choosing the stack
date: 2026-10-04
summary: Why this blog is Astro on S3 and CloudFront, built with Terraform, and the one resource I could not find anywhere on Google.
project: this-site
part: 1
topics: [astro, terraform, aws, cloudfront]
---

I've tried to start a blog a few times and it never stuck. Two reasons. First, they all looked like every other blog on the internet, so none of them felt like mine. Second, the content drifted toward the same posts everyone writes the day they sign up for dev.to: "How I set up my first Kubernetes cluster." I got bored of my own writing before I'd published much of it.

So this time the site had to feel unique, and it had to be a project in its own right. If I'm going to document things, the thing doing the documenting might as well be one of them. This post covers the stack, and why I picked it. It is not a tutorial. A static site on S3 with CloudFront and Origin Access Control is a well-known AWS pattern, and I don't need to document the exact same thing the rest of the internet has.

## Static, not a CMS

Every page on this site is a Markdown file in a Git repo. There's no database, no admin login and no server to patch. That's less to run and less to attack, and it's one less thing for me to babysit after work. A CMS would have been more work for a worse result.

## Astro

I wanted what other static site generators give you: write Markdown, get HTML. I also wanted real support for JavaScript interactivity, in case I want a page to do something later. Astro does both, and it only ships JS where I ask for it, so the output is still plain files.

## AWS, and why not a PaaS

CloudFront now has a free flat-rate plan, which removed most of the cost argument for hosting somewhere simpler. I could have used GitHub Pages or some other platform and been live in ten minutes. But I'd rather build it on AWS. It's more fun, and it's also the stack I use at work, so everything I learn here carries over.

## Terraform

Terraform is my IaC tool of choice. It's widely adopted across the industry, and it's what I work in all day. I also firmly believe fully declarative IaC beats tools that let you write loops and classes to describe infrastructure, like Pulumi or the AWS CDK. When I read a Terraform file, I'm reading the infrastructure. I don't have to run a program in my head first. Also, I tend to find any language that ends with "Script" just gross.

## Where Claude helped

I used Claude for two things: the boilerplate Terraform, and the design and bootstrapping of the site's UI. I'm not creative with UI, and left alone I'd have shipped something that looked like a Geocities page from 1999. I know what I'm doing on the infrastructure side, and Claude got me through the boilerplate faster. The decisions and the debugging are mine.

Declarative IaC is also a spot where LLMs tend to shine. Terraform either plans and applies or it doesn't, so bad code fails fast and there's no hidden state to reason about. Give a model good context and steering files and it can one-shot full deployments of ever increasing complexity.

## What broke: finding the Free plan in Terraform

Most of the Terraform was straightforward. The one part that wasn't, was how to enable the [CloudFront Free plan](https://docs.aws.amazon.com/AmazonCloudFront/latest/DeveloperGuide/flat-rate-pricing-plan.html).

The `aws` provider has no resource for it. Plans are managed through the [Pricing Plan Manager API](https://docs.aws.amazon.com/PricingPlanManager/latest/UserGuide/getting-started-pricingplanmanager-api.html), which is new enough that the `aws` provider doesn't support it yet. There's an [open pull request](https://github.com/hashicorp/terraform-provider-aws/pull/49235) to add it, so that may change soon. Searching for "terraform cloudfront free plan" and its variations turned up nothing useful. The path to success here was the `awscc` provider, which is to AWS what `azapi` is to Azure: both are generated straight from the cloud's API, so new features show up there before the main providers (`aws` and `azurerm`) catch up. So the stack uses two providers side by side:

```hcl
terraform {
  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 6.0"
    }
    awscc = {
      source  = "hashicorp/awscc"
      version = "~> 1.0"
    }
  }
}
```

The resource itself is small, once you know what it's called. It's [`awscc_pricingplanmanager_subscription`](https://registry.terraform.io/providers/hashicorp/awscc/latest/docs/resources/pricingplanmanager_subscription), and here's mine:

```hcl
resource "awscc_pricingplanmanager_subscription" "site" {
  plan_family = "CloudFront"
  plan_tier   = "FREE"
  usage_level = "DEFAULT"

  resource_arns = [
    aws_cloudfront_distribution.site.arn,
    aws_wafv2_web_acl.site.arn,
  ]
}
```

> **Unhelpful blogs**
>
> I did find a blog post on 'how to enable the CloudFront free-plan via Terraform'. But the blog basically said 'go into the AWS console and enable the plan'. That's not 'via Terraform'.

The Free plan has other limits that shaped the design, and those get their own post.

## What this settled

The stack is Astro for the site, S3 and CloudFront for hosting, and Terraform for the infrastructure, with Claude on the boilerplate and the UI. None of it is novel, and that's fine. I wanted the blog to be unique in what's on it and how it looks, not in how it's served.

Next up is the hosting itself: the private S3 bucket, CloudFront with OAC in front of it, and the WAF.

## References

- [CloudFront flat-rate pricing plans](https://docs.aws.amazon.com/AmazonCloudFront/latest/DeveloperGuide/flat-rate-pricing-plan.html), AWS documentation
- [Getting started with the PricingPlanManager API](https://docs.aws.amazon.com/PricingPlanManager/latest/UserGuide/getting-started-pricingplanmanager-api.html), AWS documentation
- [`awscc_pricingplanmanager_subscription`](https://registry.terraform.io/providers/hashicorp/awscc/latest/docs/resources/pricingplanmanager_subscription), Terraform Registry
- [New Resource: `aws_pricingplanmanager_subscription` (#49235)](https://github.com/hashicorp/terraform-provider-aws/pull/49235), pull request on `terraform-provider-aws`
