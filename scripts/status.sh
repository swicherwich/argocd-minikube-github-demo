#!/usr/bin/env bash
# One-screen overview of the demo: ArgoCD pods, Applications and the app workloads.
set -euo pipefail
# shellcheck source=env.sh
source "$(dirname "${BASH_SOURCE[0]}")/env.sh"

log "ArgoCD Applications"
k -n argocd get applications 2>/dev/null || warn "No Applications yet (run: make bootstrap)"
echo
log "ArgoCD pods"
k get pods -n argocd
echo
for ns in mlflow-dev mlflow-staging; do
  log "Namespace ${ns}"
  k get all -n "$ns" 2>/dev/null || echo "  (not created yet)"
  echo
done
