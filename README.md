# flake-cooldown

Updates a flake's `flake.lock` with a cooldown on third-party inputs: each
direct GitHub input is pinned to a version at least a few days old (5 by
default), so a malicious commit has time to be noticed before it is picked up.

- nixpkgs on a `nixos-YY.MM[-small]` or `nixos-unstable[-small]` channel goes
  to the newest channel release published before the cutoff, going by its
  upload time on releases.nixos.org.
- Other GitHub inputs go to the newest first-parent commit on their branch
  dated before the cutoff.
- Inputs of an exempt owner (by default the repository's own) update to their
  latest commit. Their own inputs, nixpkgs included, are whatever their lock
  file says, so only exempt repositories that run this cooldown themselves.
- Non-GitHub inputs are updated normally.

See [`cooldown_update.py`](cooldown_update.py) for details.

## GitHub Actions

```yaml
name: Update flake

on:
  workflow_dispatch:
    inputs:
      cooldown_days:
        description: Only take third-party commits at least this many days old (0 for an urgent update).
        type: number
        default: 5
  schedule:
    - cron: '17 4 * * 1'

permissions:
  contents: read

jobs:
  update:
    runs-on: ubuntu-24.04
    permissions:
      contents: write
      pull-requests: write
    steps:
      - uses: actions/checkout@v7
      - uses: cachix/install-nix-action@v31
      - uses: yawkat/flake-cooldown@<commit>
        id: update
        with:
          cooldown-days: ${{ inputs.cooldown_days }}
      - uses: peter-evans/create-pull-request@v8
        with:
          branch: update_flake_lock_action
          delete-branch: true
          title: flake update
          body: ${{ steps.update.outputs.body }}
```

The action commits the updated lock file; `body` is a PR description, empty if
nothing changed. Pin the action to a commit: it runs with the job's write
permissions.

Inputs:

| Input | Default | |
|---|---|---|
| `cooldown-days` | 5 | Minimum age of third-party versions. 0 for an urgent update. |
| `exempt-owner` | repository owner | Owner whose inputs update to their latest commit. Empty for none. |
| `commit-user-name` / `commit-user-email` | `github-actions[bot]` | Identity of the lock file commit. |

## Locally

In the flake directory, with a clean `flake.lock`:

```sh
EXEMPT_OWNER=yawkat nix run github:yawkat/flake-cooldown
```

`COOLDOWN_DAYS` sets the cooldown. The update is committed with your git
identity.
