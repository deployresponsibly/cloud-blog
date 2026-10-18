---
title: Terraform is not your orchestrator
date: 2026-10-18
summary: Why a subscription vending pipeline run from Terraform eventually sucks, and what moving the orchestration into a CI/CD pipeline fixes.
topics: [terraform, azure, aws, cicd, pipelines]
draft: false
---

Terraform is very good at one thing: describing, then creating the desired end state of infrastructure. The trouble starts when you ask it to also be the thing that decides what happens next, and in what order. I recently rebuilt an Azure subscription vending pipeline that had grown up around that mistake, and this post is about why the old design was garbage and what the new one looks like.

A subscription vending pipeline takes a request ("I need a landing zone for this workload") and produces a ready subscription and landing zone: created, placed in the right management group, networked, with its address space registered somewhere so nothing overlaps. Most of that is infrastructure, so it's natural to reach for Terraform. The old pipeline did exactly that, with a root Terraform configuration as the orchestrator and everything else hanging off it.

## Where it went wrong

Vending isn't only infrastructure. Somewhere along the way you need to call an IP address management system to reserve a CIDR, or look something up in an inventory, or notify somebody. Those are REST calls, and Terraform has ways to make them: the [`restapi` provider](https://registry.terraform.io/providers/Mastercard/restapi/latest) from Mastercard, `http` data sources, `local-exec` provisioners. They work, but perhaps that's the problem.

Terraform's model is declarative. It reads the current state, compares it to what you described, and works out a plan. That only makes sense if the thing on the other end behaves like a resource:

- Reading it twice gives the same answer.
- Creating something that already exists is either rejected or a no-op.
- Deleting it undoes the create.

Plenty of REST endpoints don't behave that way. An endpoint that hands out "the next free CIDR" returns a different answer every time you call it. An endpoint that creates a record might not support reading it back by a stable key, so Terraform can't tell whether the record exists. Even when the API is idempotent and fits the provider, you end up writing a resource definition for something that isn't really a resource, and the plan output tells you very little about what will actually happen.

The pipeline I worked on had a lot of imperative innards squeezed into a declarative body: `terraform_data` and `null-resource` "resources" with triggers to force re-runs, `depends_on` chains to fake ordering, and outputs from one apply fed into the inputs of the next. It worked, mostly. As long as you babysat it the whole time due to a near 33% failure rate. Debugging it meant reading a plan that described a model of the process instead of the process.

## The step Terraform can't express

The clearest example is what happens after a virtual network gets its address space. In enterprise environments, often the new CIDR has to be opened up in the firewall, and that happens by submitting a request to whoever owns the firewall and waiting for them to act on it. #CRQ

That step doesn't provision anything. It sends a message. Running it twice sends two requests. There's no state to compare against, no meaningful `destroy`, and no way to describe "a request has been submitted" as a desired end state in a way Terraform can reason about (there actually are, but its usually going to be messy and gross). It's a plain action with a side effect.

You could force it into a `local-exec` provisioner, and I've seen it done more often than I prefer. But then it only runs on create, it's invisible in the plan, and a failed request means tainting a resource that has nothing to do with the problem. This is the point where you need to stop trying to make Terraform fit and reach for a proper orchestrator.

## Moving the orchestration out

The replacement is a CI/CD pipeline: Azure DevOps, GitHub Actions or CodePipeline would all do the job. A pipeline is imperative by design. It runs stages in order, passes values between them, branches on conditions, and records what happened on each step. That's the right shape for a process.

The split I settled on:

| Where it lives | What it does |
| --- | --- |
| Pipeline YAML | Calls REST APIs, passes values between steps, submits requests, decides what runs and in what order |
| Terraform | Creates and manages the actual infrastructure resources, taking the values the pipeline gives it as plain input variables |

Every REST call that used to be hidden inside Terraform became an explicit pipeline step. The CIDR reservation runs first and writes its result as an output variable. Terraform then runs with that value as an input, and does only what it's good at. The Terraform configuration got smaller and boring, which is what I wanted. Its plan now describes only infrastructure, so reading it tells you what will change in Azure and nothing else.

A few things got better right away:

- **Failures are visible where they happen.** A failed reservation fails the reservation step, with the API's response in the log, instead of surfacing as a provider error halfway through an apply.
- **Retries are deliberate.** Each step can have its own retry and timeout behavior, and I can re-run from a stage instead of re-planning everything. The pain is real when the TF plan phase just took 45 minutes and it fails during the apply.
- **Approvals fit naturally.** Pipelines already have environments, gates and manual approvals. Terraform has no real equivalent (unless you're using a managed Terraform service like HCP Terraform)
- **The process is readable.** The pipeline file reads top to bottom as the sequence of things that happen, which is the documentation the old setup never had.

## What this made possible

Once orchestration lived in the pipeline, the firewall step became just another stage at the end: take the CIDR from the earlier step, submit the request, and report that it was submitted. It runs after the infrastructure exists, it isn't pretending to be idempotent, and if it fails, nothing in the Terraform state is affected. That feature wasn't achievable in the old design without hacks. In the new one it was an afternoon's work.

## When Terraform as the orchestrator is fine

I'm not saying you should never call an API from Terraform. If the endpoint really is a resource (stable key, readable, idempotent create, a delete that undoes it) and a provider models it well, then a resource block is the simplest option and you get drift detection for free. A single REST call in a small configuration is not a design problem.

The warning signs are worth knowing:

- You're adding triggers or `depends_on` entries to force a step to run at the right time.
- A resource exists only to run a command.
- The result of an API call decides what the rest of the configuration does.
- You need something to happen once, after everything else, and don't want it undone on destroy.

If you recognize two or more, you're probably orchestrating, and Terraform isn't the tool for that.

## The short version

Let Terraform own the resources, and let a pipeline own the process. Declarative tools are strong because they don't care about order or history, and processes are all about order and history.
