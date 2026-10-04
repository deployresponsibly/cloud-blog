---
title: Hosting on S3 and CloudFront
date: 2026-10-04
summary: A private S3 bucket behind CloudFront with Origin Access Control, and the small function that makes directory-style URLs work.
project: this-site
part: 2
topics: [aws, s3, cloudfront]
---

This is the meat of the project. S3 for storing the HTML/CSS/JS, and CloudFront to server it to readers. And I would love to hype up the drama I went through to get this done, to tell you about the weeks I lost debugging this part. But no. I didn't lose any. S3 behind CloudFront is a pattern I know well, and I know where the 'gotchas' are, so this post will be short on drama. It covers the two decisions that matter, plus one small function you may need if your site has more than one page.

If you read [part 1](/posts/choosing-the-stack/), you know why the site is static and why it lives on AWS. This part is how the files get from the bucket to the browser.

## A private bucket, and only CloudFront can read it

The bucket has no public access at all. Block Public Access is on for the bucket (in fact its a setting enabled on the entire AWS account for all my buckets), so a mistake later can't quietly turn it public. Objects are encrypted, ACLs are disabled, and a bucket policy denies any request that isn't over TLS.

The only way in is through CloudFront, using [Origin Access Control](https://docs.aws.amazon.com/AmazonCloudFront/latest/DeveloperGuide/private-content-restricting-access-to-s3.html). CloudFront signs every request it sends to S3, and the bucket policy allows the CloudFront service to read objects, but only on behalf of this one distribution:

```hcl
{
  Sid       = "AllowCloudFrontServicePrincipalReadOnly"
  Effect    = "Allow"
  Principal = { Service = "cloudfront.amazonaws.com" }
  Action    = "s3:GetObject"
  Resource  = "${aws_s3_bucket.site.arn}/*"
  Condition = {
    StringEquals = { "AWS:SourceArn" = aws_cloudfront_distribution.site.arn }
  }
}
```

There's an older way to do this that you'll still find in plenty of misguided tutorials. You turn on the bucket's [website endpoint](https://docs.aws.amazon.com/AmazonS3/latest/userguide/WebsiteEndpoints.html), make the bucket public, and have CloudFront send a secret header, often `Referer`, with a random string in it. The bucket policy only allows requests that carry that string. I didn't want to do it that way:

- The secret sits in plain text in both the distribution and the bucket policy, and it's yours to rotate and keep safe.
- The bucket is public. Anything wrong with that policy exposes the whole site's origin to the internet.
- Website endpoints don't support HTTPS, so CloudFront reaches the bucket without TLS. Not likely a huge issue for most, but something to be aware of.

With OAC there's no shared secret and the bucket is never public. The only thing that can read it is the one distribution named in the policy.

To be fair... a website endpoint does serve index documents on its own, which is the maybe the ONLY reason people would still implement it. I believe this to be a poor reason, and there's virtually no real reason to enable the website endpoint on S3 buckets anymore. There's just 1 caveat when serving directory-style URLs:

## `/` is not an object

S3 doesn't have folders. It has keys. Astro builds `/posts/hosting-on-s3-and-cloudfront/index.html`, and a browser asks for `/posts/hosting-on-s3-and-cloudfront/`. S3 looks for a key called `posts/hosting-on-s3-and-cloudfront/`, finds nothing, and says no.

CloudFront has a setting called a [default root object](https://docs.aws.amazon.com/AmazonCloudFront/latest/DeveloperGuide/DefaultRootObject.html), and I set it to `index.html`. It only applies to the root of the site, so `/` works. It does nothing for `/posts/` or `/about/`, which is most of the site. Every page except the homepage would be broken.

The fix is a [CloudFront Function](https://docs.aws.amazon.com/AmazonCloudFront/latest/DeveloperGuide/cloudfront-functions.html) that runs on every viewer request and rewrites the URI before it reaches S3:

```js
function handler(event) {
  var request = event.request;
  var uri = request.uri;
  if (uri.endsWith('/')) {
    request.uri += 'index.html';
  } else if (!uri.split('/').pop().includes('.')) {
    request.uri += '/index.html';
  }
  return request;
}
```

A URI ending in `/` gets `index.html` added. A URI with no file extension, like `/about`, gets `/index.html` added. Anything with a dot, like `style.css` or `rss.xml`, passes through as is. The browser's address bar never changes, because the rewrite happens inside CloudFront.

If you've hosted a single-page app on S3, this will sound familiar, because it's the same problem. The browser asks for a path that isn't a key in the bucket, and S3 has nothing to give it. An SPA only has one `index.html`, so its version of this function sends every path that isn't a real file to `/index.html` and lets the JavaScript router take over from there. This site has an `index.html` in every directory, so each path gets sent to its own: `/about` goes to `/about/index.html`. Same problem, slightly different function.

The same function also redirects `www` to the bare domain.

## A couple of other settings

The distribution redirects HTTP to HTTPS, requires TLS 1.2 or newer, and speaks HTTP/2 and HTTP/3. It uses AWS's managed cache and security header policies instead of rules I'd have to maintain. Requests for pages that don't exist come back from S3 as 403, not 404, because the bucket policy doesn't grant `s3:ListBucket`. A custom error response turns both into the site's own 404 page.

## What this settled

The bucket is private, CloudFront is the only reader, and one small function makes every page reachable. The next part is about what the CloudFront Free plan lets you do, and what it doesn't.

## References

- [Restrict access to an Amazon S3 origin](https://docs.aws.amazon.com/AmazonCloudFront/latest/DeveloperGuide/private-content-restricting-access-to-s3.html), AWS documentation
- [Customize at the edge with CloudFront Functions](https://docs.aws.amazon.com/AmazonCloudFront/latest/DeveloperGuide/cloudfront-functions.html), AWS documentation
- [CloudFront default root objects](https://docs.aws.amazon.com/AmazonCloudFront/latest/DeveloperGuide/DefaultRootObject.html), AWS documentation
- [Website endpoints](https://docs.aws.amazon.com/AmazonS3/latest/userguide/WebsiteEndpoints.html), AWS documentation
