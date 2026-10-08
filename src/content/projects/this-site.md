---
title: This site
question: Can a blog be its own first cloud project?
summary: How this blog is built, hosted and deployed on AWS, with the infrastructure code in the same repository.
status: in-progress
started: 2026-10-02
updated: 2026-10-04
stack: [Astro, Terraform, AWS, S3, CloudFront, WAF, Route 53, GitHub Actions, CodeBuild]
repo: https://github.com/deployresponsibly/cloud-blog
architecture:
  caption: How a post gets from a Markdown file to a reader. Builds run on GitHub; only the deploy job holds AWS credentials.
  zones:
    - { id: aws, label: AWS }
  nodes:
    - { id: repo, label: GitHub repo, col: 1, row: 1 }
    - { id: build, label: Astro build, col: 2, row: 1, post: choosing-the-stack }
    - { id: deploy, label: CodeBuild runner, col: 3, row: 1, zone: aws }
    - { id: storage, label: S3 bucket, col: 4, row: 1, zone: aws, post: hosting-on-s3-and-cloudfront }
    - { id: cdn, label: CloudFront + WAF, col: 4, row: 2, zone: aws, post: hosting-on-s3-and-cloudfront }
    - { id: dns, label: Route 53, col: 3, row: 2, zone: aws }
    - { id: reader, label: Reader, col: 4, row: 3, accent: true }
  edges:
    - { from: repo, to: build, label: push to main }
    - { from: build, to: deploy, label: artifact }
    - { from: deploy, to: storage, label: s3 sync }
    - { from: reader, to: dns, label: lookup }
    - { from: reader, to: cdn, label: request }
    - { from: cdn, to: storage, label: origin, dashed: true }
decisions:
  - text: Static site over a CMS
    post: choosing-the-stack
  - text: Private S3 bucket behind CloudFront with Origin Access Control
    post: hosting-on-s3-and-cloudfront
  - text: CloudFront's Free flat-rate plan
    post: living-inside-the-cloudfront-free-plan
  - DNS left in the existing account, reached through a second Terraform provider
  - Terraform state in S3 with native locking, no DynamoDB
  - GitHub builds with no AWS access, a CodeBuild runner deploys
  - Every GitHub Action pinned to a commit SHA
planned:
  - The deploy pipeline
  - What broke along the way
---

A typical "dev" blog, and my attempt at getting my thoughts and learnings down on record. I've made attempts at this before and it's always been left behind. I don't write particularly well, and my actual job keeps me busy. But we're giving this a go one more time.

This blog's deployment pattern is your typical S3 static website. It's an Astro site served from a private S3 bucket through CloudFront via OAC. Terraform defines the whole stack, a pull request runs the checks, and a push to `main` deploys.
