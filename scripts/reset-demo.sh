#!/usr/bin/env bash
# Put the demo back to its starting point after a run-through: your demo branch goes
# back to the commit it had when you ran `make bootstrap`, and ArgoCD syncs the cluster
# to match. This REWRITES the branch on GitHub (force push), so it only runs on a
# dedicated demo branch, never on main/master.
set -euo pipefail
# shellcheck source=env.sh
source "$(dirname "${BASH_SOURCE[0]}")/env.sh"

[[ -f "$WORK_DIR/demo-start-sha" ]] || die "No recorded starting point. Run: make bootstrap"
start_sha="$(cat "$WORK_DIR/demo-start-sha")"
branch="$(cat "$WORK_DIR/demo-branch")"

case "$branch" in
  main|master) die "Refusing to force-push '${branch}'. Use a dedicated demo branch (git switch -c demo)." ;;
esac
[[ "$(git -C "$ROOT_DIR" symbolic-ref --short -q HEAD || true)" == "$branch" ]] \
  || die "Check out the demo branch first: git switch ${branch}"
[[ -z "$(git -C "$ROOT_DIR" status --porcelain)" ]] \
  || die "You have uncommitted changes. Commit or stash them first, reset would discard them."

log "Resetting '${branch}' to ${start_sha:0:7} and force-pushing to GitHub"
git -C "$ROOT_DIR" reset -q --hard "$start_sha"
git -C "$ROOT_DIR" push -q --force-with-lease origin "HEAD:${branch}"

log "ArgoCD picks the change up on its next poll (30s). Watch the UI, or run: make status"
log "mlflow-staging is manual: press Sync there if you synced it during the demo."
