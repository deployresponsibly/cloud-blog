---
title: FreeBSD NAS
question: What does it take to build a NAS from scratch, on FreeBSD, instead of simply installing a NAS OS?
summary: Building my new NAS on FreeBSD, with no appliance/NAS distro doing the work for me. The rules I set, the hardware and software I chose, and a high-level look at what I did.
status: in-progress
started: 2026-10-07
stack: [FreeBSD]
decisions:
  - text: Plain FreeBSD, no NAS distribution
    post: the-rules
planned:
  - The hardware and software
  - The setup
  - What I'd do differently
---

I'm building a NAS from scratch on FreeBSD, configuring each piece myself instead of clicking through an appliance's web UI. The point is to understand every layer of the thing that holds my data, and to end up with a box I can explain end to end.

This project is a short series, not a tutorial. It covers the rules I set for myself, what I chose and why, and a high-level look at the setup, without a command-by-command rundown.
