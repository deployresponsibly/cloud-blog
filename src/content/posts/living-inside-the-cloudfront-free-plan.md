---
title: Living inside the CloudFront Free plan
date: 2026-10-04
summary: What the CloudFront Free plan takes away, what it leaves you, and why I don't care.
project: this-site
part: 3
topics: [aws, cloudfront, waf]
---

The Free plan costs nothing, so I'm not going to pretend I negotiated anything. What I can do is list what it takes away. Most of that list is stuff a personal blog doesn't need, but a few items do have noticeable consequences.

The plan bundles CloudFront, a WAF web ACL, DDoS protection, a TLS certificate and some Route 53 coverage into one flat monthly price, and in the Free tier that price is zero. The [full feature table](https://docs.aws.amazon.com/AmazonCloudFront/latest/DeveloperGuide/flat-rate-pricing-plan.html#pricing-plan-features) is long. This is the short version.

## What you give up

- Custom response headers. You get AWS's managed security headers policy, so HSTS, `X-Content-Type-Options`, `X-Frame-Options` and a referrer policy all show up. A `Content-Security-Policy` isn't one of them, and writing your own response headers policy is a Business-tier feature.
- Access logs and WAF logs. Both start at Pro. I can't answer "how many people read this?" from CloudFront (though I have my suspicions...), and I can't go digging through requests after something odd happens. The security dashboard is included, which helps with the second one a little.
- More than five WAF rules. This site runs three AWS managed rule groups and a per-IP rate limit, which is four of five. Header filtering, CAPTCHA, bot control and regex matching all live in higher tiers.
- Custom cache policies. Free only gets the managed defaults, so the site uses `Managed-CachingOptimized`. You also get five cache behaviors, and I use one. A distribution on the legacy `ForwardedValues` cache settings is rejected outright, so the plan wants cache policies either way.
- One distribution and one apex domain per plan, and three Free plans per AWS account. `www` and the bare domain share the same apex, so they fit.
- A hosted zone in the plan, if your zone is in another account. The zone has to be in the same account as the distribution to be attached, and mine isn't. Route 53 stays on regular pay-as-you-go pricing, which is a small bill but not a zero one.
- Guaranteed headroom. The plan includes 1 million requests and 100 GB of transfer a month. AWS says those aren't hard limits and there are no overage charges, but if you stay far above them for months, delivery can be adjusted, such as being served from fewer or more distant edge locations. A blog with a handful of readers isn't going to get there.
- An SLA, and support beyond billing questions.

## What you keep

The CDN itself, caching, fast invalidations, DDoS protection and a WAF with managed rules and rate limiting are all there. So are Origin Access Control, a free TLS certificate, HTTP/2, HTTP/3, IPv6 and CloudFront Functions, which the [previous part](/posts/hosting-on-s3-and-cloudfront/) leaned on. For a static blog, that's the whole job. The plan won't let you skip the WAF, and I'm not particularly upset about being forced into free security.

## What this settled

For a low traffic blog, the free tier is more than sufficient. Though logging would be nice. I like looking through logs.

Next up is the deploy pipeline.

## References

- [CloudFront flat-rate pricing plans](https://docs.aws.amazon.com/AmazonCloudFront/latest/DeveloperGuide/flat-rate-pricing-plan.html), AWS documentation
- [Getting started with the PricingPlanManager API](https://docs.aws.amazon.com/PricingPlanManager/latest/UserGuide/getting-started-pricingplanmanager-api.html), AWS documentation
