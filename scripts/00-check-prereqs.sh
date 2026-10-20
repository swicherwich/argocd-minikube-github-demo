#!/usr/bin/env bash
# Verify that the tools this demo needs are installed, and that your clone is ready.
set -euo pipefail
# shellcheck source=env.sh
source "$(dirname "${BASH_SOURCE[0]}")/env.sh"

missing=0
for tool in docker minikube kubectl terraform git curl; do
  if command -v "$tool" >/dev/null 2>&1; then
    printf '  ok       %s\n' "$tool"
  else
    printf '  MISSING  %s\n' "$tool"
    missing=1
  fi
done
[[ $missing -eq 0 ]] || die "Install the missing tools listed above (see README, Prerequisites)."

if ! docker info >/dev/null 2>&1; then
  warn "Docker does not seem to be running. Start Docker Desktop (or your container runtime), or set MINIKUBE_EXTRA_ARGS to use another minikube driver."
fi

# The repository ArgoCD will watch is YOUR fork, read from this clone's origin remote.
detect_repo
log "ArgoCD will watch: ${REPO_URL}  (branch: ${GIT_BRANCH})"
case "$GIT_BRANCH" in
  main|master) warn "You are on '${GIT_BRANCH}'. Demo commits will land there. A dedicated branch is cleaner: git switch -c demo && git push -u origin demo" ;;
esac

log "Prerequisites look good."
