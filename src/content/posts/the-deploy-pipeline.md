---
title: The deploy pipeline
date: 2026-10-08
summary: How a push to main becomes a live site.
project: this-site
part: 4
topics: [github-actions, codebuild, aws]
architecture:
  caption: CI runs on every pull request. Merging to main triggers the Deploy workflow. GitHub builds the site, and only the deploy job, running on CodeBuild, touches AWS.
  zones:
    - { id: github, label: GitHub }
    - { id: aws, label: AWS }
  nodes:
    - { id: pr, label: Pull request, col: 1, row: 1, zone: github, accent: true }
    - { id: ci, label: CI checks, col: 2, row: 1, zone: github }
    - { id: main, label: Merge to main, col: 1, row: 2, zone: github }
    - { id: build, label: Build job, col: 2, row: 2, zone: github }
    - { id: deploy, label: Deploy job, col: 3, row: 2, zone: aws }
    - { id: site, label: S3 + CloudFront, col: 3, row: 3, zone: aws }
  edges:
    - { from: pr, to: ci, label: checks }
    - { from: pr, to: main, label: merge }
    - { from: main, to: build, label: triggers }
    - { from: build, to: deploy, label: artifact }
    - { from: deploy, to: site, label: sync }
draft: false
---

Automation, automation, automation. I'm lazy as shit. I don't want to constantly have to manually run a bunch of commands every time I update the site.
Therefore, I'm using a simple pipeline to automate every step needed to get an update live once I merge a pull request.

## Checks on every pull request

When I open a pull request, two CI (continuous integration) jobs run, as defined in `.github/workflows/ci.yml`. Neither one has any AWS access.

The `site` job calls the required `npm run build`, which compiles my application from the raw markdown and Astro components into a browser friendly website.

The `terraform` job calls basic Terraform commands like `terraform fmt -check -recursive`, which ensures the `.tf` files are all formatted. Then it calls `init` and `validate`, which installs the required providers and validates the code is... valid.

I have this CI step during the PR phase to ensure all code is valid and working as expected. Since this is a basic non-prod site, there is no real need for any extensive testing which would normally be included in the CI phase.

## Build here, deploy there

Once the PR is merged to `main`, we have our CD phase (continuous deployment), defined in `.github/workflows/deploy.yml`. This is a two job split. The first job builds the site (again), and the second deploys it. Changes to `infra/`, `.tf` files and the README don't trigger it. There's nothing to deploy for those.

I've split it in two to keep access to my AWS account as narrow as possible. The first job is a GitHub hosted build with zero AWS access. It's the one that runs `npm`, which means every package I pull in only ever executes somewhere that has nothing worth stealing. It uploads the finished `dist/` folder as an artifact.

The second job is a [CodeBuild hosted runner](https://docs.aws.amazon.com/codebuild/latest/userguide/action-runner.html) that downloads the build artifact and deploys it. To make that work, there's a CodeBuild project (defined in Terraform, like everything else) with a webhook attached. When a job from the `Deploy` workflow gets queued on GitHub, the webhook tells CodeBuild to spin up a runner and pick it up.

## A role scoped to one bucket and one distribution

That runner works under its own IAM role, and the role is boring on purpose. Only CodeBuild can assume it, and only for this one CodeBuild project in my account. That’s the standard guard against the [confused deputy problem](https://docs.aws.amazon.com/IAM/latest/UserGuide/confused-deputy.html), where a service you trust gets tricked into using your role on someone else’s behalf.

As for what the role can actually do:

- List the site's bucket, and put and delete objects in it. Delete is there because the sync removes files that no longer exist.
- Create invalidations on the one CloudFront distribution.
- Use the GitHub connection, so the runner can talk to GitHub.
- Write logs to its own log group.

That's it. No wildcards on resources, no reading anything else in the account. If that job ever got compromised, the worst it could do is mess with the website. I'm okay with that blast radius.

## Caching: assets for a year, pages never

The deploy job is three commands: two [`aws s3 sync`](https://docs.aws.amazon.com/cli/latest/reference/s3/sync.html) passes and an invalidation.

Astro fingerprints everything in `_astro/` (the CSS and JS), so the file name changes whenever the contents do. That means those files can never be stale, so the first sync uploads them with `public,max-age=31536000,immutable`. Cache them for a year, don't even ask.

The second sync uploads everything else (the HTML pages) with `public,max-age=0,must-revalidate`. Page URLs never change, but their contents do, so browsers have to check in with CloudFront every time. Both syncs use `--delete`, so anything I remove from the site gets removed from the bucket too.

Last step is an [invalidation](https://docs.aws.amazon.com/AmazonCloudFront/latest/DeveloperGuide/Invalidation.html) (`aws cloudfront create-invalidation`) on `/*`, which tells CloudFront to drop its copies of everything. Eeeh... its probably belt and suspenders given the headers, but invalidations are fast and included in the Free plan, so I'll take the insurance.

## Pinning every action to a commit SHA

Every `uses:` line in my workflows points at a full [commit SHA](https://docs.github.com/en/actions/reference/security/secure-use), with the version tucked into a comment so I can still read it. Tags like `v4` are just pointers, and the person who owns the action can move them. If their account gets compromised, the tag I trusted yesterday can run something very different today, on a runner that may have my secrets. A commit SHA can't be moved.

Pinning on its own is just a habit though, and I'd rather not rely on remembering. So the repository's Actions settings [require it](https://github.blog/changelog/2025-08-15-github-actions-policy-now-supports-blocking-and-sha-pinning-actions/). Any workflow that uses an action not pinned to a full SHA fails outright.

## What this settled

At the end of the day, this is a very basic deploy pipeline. 2 workflows (CI and CD), and both contain 2 jobs each. No tests other than running `npm run build` and `terraform validate` to ensure both application and infrastructure at least "appear" to work.

It also doesn't apply Terraform. CI only checks that the infrastructure code is valid, and applying it is still me, by hand. For a site this size, that's a trade I'm happy to make. In fact, you could make a very good argument that the Terraform jobs are totally pointless. Those 3 commands take me seconds to run locally.

Next up is what broke along the way, because plenty did.

## References

- [Self-hosted GitHub Actions runners in AWS CodeBuild](https://docs.aws.amazon.com/codebuild/latest/userguide/action-runner.html), AWS documentation
- [The confused deputy problem](https://docs.aws.amazon.com/IAM/latest/UserGuide/confused-deputy.html), AWS documentation
- [`aws s3 sync`](https://docs.aws.amazon.com/cli/latest/reference/s3/sync.html), AWS CLI reference
- [Invalidate files](https://docs.aws.amazon.com/AmazonCloudFront/latest/DeveloperGuide/Invalidation.html), AWS documentation
- [Secure use reference](https://docs.github.com/en/actions/reference/security/secure-use), GitHub documentation
- [GitHub Actions policy now supports blocking and SHA pinning actions](https://github.blog/changelog/2025-08-15-github-actions-policy-now-supports-blocking-and-sha-pinning-actions/), GitHub changelog
