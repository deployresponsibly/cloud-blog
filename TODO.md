# TODO

Security follow-ups.

- [x] **Branch protection on `main`**: requires the `CI` checks and a pull
      request, and blocks direct pushes and force pushes, including for admins.
      Deploys run on every push to `main`, so this is the main guard on
      production.
- [x] **Fork PR approval**: "Require approval for all external contributors" is
      set under Settings > Actions > General. The CodeBuild runner is only
      reachable from the `Deploy` workflow, but this closes the fork-PR path.
- [ ] Limit the AWS Connector for GitHub app to this repository only
      (GitHub > Settings > Applications > Installed GitHub Apps).
