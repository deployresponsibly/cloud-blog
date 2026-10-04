# Working in this repo

This repository is public, and its owner keeps personal and employer details out of it on purpose. Treat every file, commit message, branch name and PR title or body as public. Do these checks before every commit and before opening or updating a PR.

## Pre-commit checks

1. **Run the scanner on what is staged.**
   ```sh
   scripts/check-sensitive.sh
   ```
   It fails on forbidden tracked files, a git identity that isn't the GitHub noreply address, secret and credential patterns, AWS account IDs and ARNs, email addresses, and anything listed in `.local/sensitive-patterns.txt`. Fix every finding before committing. Run it with `--all` after large changes or when touching `infra/`.
2. **Don't stage generated or local files.** `terraform.tfvars`, `backend.hcl`, state files, `.terraform/`, `.local/` and `TODO.md` are git-ignored. If `git status` shows any of them, stop.
3. **Check the commit identity.** `git config user.email` in this repo must be the GitHub noreply address. Never commit with a global identity, and never put another name or email in a commit, a trailer or a PR.
4. **Read the diff yourself.** The scanner can't judge context. Look for the items under "Review by hand" below.
5. **Check the text that isn't in files.** The commit message, branch name and PR title and body are public too. Run the same checks on them.

## Review by hand

- Employer or workplace details: company or team names, internal systems, tool or vendor choices that point at one organization, colleagues, ticket numbers, and anything about critical infrastructure. Write about techniques, not about where they were used. If unsure, ask.
- Personal details: exact job titles, schools, locations, dates that narrow down who someone is, photos and image metadata (strip EXIF).
- Pasted tool output: `terraform plan`, `terraform output`, `aws` CLI results, console screenshots and logs. Redact account IDs, ARNs, resource and distribution IDs, bucket names that include an account ID, profile names, IPs, and email addresses.
- Infrastructure code: hardcoded account-specific values belong in git-ignored `terraform.tfvars` or `backend.hcl`, with a `.example` file showing the shape.
- Links to private repositories, internal hostnames or old accounts.

## The local patterns file

`.local/sensitive-patterns.txt` is git-ignored and holds the values specific to the owner: old handles, account IDs, profile names, domains. It is one extended regex per line.

- When a new sensitive value appears (a new account, profile, domain or handle), add it there.
- Never print, quote or copy its contents into a commit, a PR, a post, an issue or a chat message that will be committed.
- If the file is missing, the scanner warns. Tell the owner and don't skip the check.

## Git workflow

- `main` is protected: changes go through a pull request, and the `site` and `terraform` CI checks must pass. Direct pushes and force pushes are blocked, including for the owner.
- A merge to `main` runs the `Deploy` workflow, which publishes the site, so merge only when the owner has approved the change.
- Create a branch, commit, push, open a PR, wait for CI, then squash-merge.
