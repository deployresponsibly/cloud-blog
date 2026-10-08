---
title: The rules
date: 2026-10-08
summary: The rules I set before touching any hardware, and why I set them.
project: freebsd-nas
part: 1
topics: [freebsd, nas]
draft: false
---

Most of my life I've been plagued with thoughts like, "get it done as fast as possible!", or "order rush shipping!" (pre-Amazon prime days of course), or "reading the docs only slows me down".
This is probably even evident in my career choice. As a Cloud Engineer, I work with abstractions. I learn how to (relatively) quickly put together hundreds of individual things other people took months and years to build. This leads to quick satisfaction. Sure. But sometimes it's nice to step back and take my time. This need to do things fast is even more evident in the age of LLMs and agentic AI.

With that in mind, these rules are for me. They're intended to slow me down, and to help me remember that actually using my brain is still important. Even if I can't push an update as fast.

So, let's look at what the NAS is for, and then the rules themselves.

## What the NAS is for

This is your typical home NAS, using the modern version of the term. That means hosting VMs as well as data. It's going to host Linux ISOs, [Jellyfin](https://jellyfin.org/), and maybe some dedicated game servers for myself and my friends.

## The rules

- No AI for this project. It will be the toughest rule to keep. As much as I hate to say it, AI makes greenfield projects like this MUCH easier.
- [FreeBSD Handbook](https://docs.freebsd.org/en/books/handbook/) (and potentially other documentation), `man` pages, and generic blog posts only. So no step-by-step directions on building a NAS, no YouTube tutorials, no running scripts someone wrote that bootstraps the server. An acceptable blog post would be something like, *[How to Set Up NFS File Sharing on FreeBSD](https://www.freebsdsoftware.org/blog/nfs-freebsd-setup.html)*.
- No NAS distros or appliance OSes. It's plain FreeBSD, configured by hand.
- No new hardware that I don't have on hand.
- No GUI. All work (aside from initial setup) will be over SSH. No X Window System either.

## References

- [FreeBSD Handbook](https://docs.freebsd.org/en/books/handbook/)
- [How to Set Up NFS File Sharing on FreeBSD](https://www.freebsdsoftware.org/blog/nfs-freebsd-setup.html) (freebsdsoftware.org)
