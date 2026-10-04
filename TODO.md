# TODO

Security follow-ups that need GitHub features this private repo can't use yet.

- [ ] **Branch protection on `main`**: require the `CI` checks and block direct
      pushes. Needs GitHub Pro, or make the repo public. Deploys run on every
      push to `main`, so this is the main guard on production.
- [ ] **Fork PR approval**: once the repo is public, set Settings > Actions >
      General > "Require approval for all external contributors". GitHub rejects
      this setting on private repos. The CodeBuild runner is only reachable from
      the `Deploy` workflow, but this closes the fork-PR path.
- [ ] Limit the AWS Connector for GitHub app to this repository only
      (GitHub > Settings > Applications > Installed GitHub Apps).
