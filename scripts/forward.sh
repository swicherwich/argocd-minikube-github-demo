#!/usr/bin/env bash
# Keep port-forwards open for the demo. Run this in its own terminal and leave it running.
# Each forward restarts itself, so services that appear later (the MLflow apps) just work.
set -euo pipefail
# shellcheck source=env.sh
source "$(dirname "${BASH_SOURCE[0]}")/env.sh"

PIDS=()
cleanup() {
  local p
  for p in ${PIDS[@]+"${PIDS[@]}"}; do
    pkill -P "$p" 2>/dev/null || true   # the kubectl child
    kill "$p" 2>/dev/null || true       # the retry loop
  done
}
trap cleanup EXIT INT TERM

# forward NAMESPACE SERVICE LOCAL_PORT REMOTE_PORT
forward() {
  (
    while true; do
      k -n "$1" port-forward "svc/$2" "$3:$4" >/dev/null 2>&1 || true
      sleep 2
    done
  ) &
  PIDS+=($!)
}

forward argocd argocd-server "$ARGOCD_LOCAL_PORT" 80
forward mlflow-dev mlflow "$MLFLOW_DEV_LOCAL_PORT" 5000
forward mlflow-staging mlflow "$MLFLOW_STAGING_LOCAL_PORT" 5000

PASS="$(k -n argocd get secret argocd-initial-admin-secret -o jsonpath='{.data.password}' 2>/dev/null | base64 -d 2>/dev/null || true)"

cat <<EOF

Port-forwards are running (Ctrl+C to stop):

  ArgoCD UI         http://localhost:${ARGOCD_LOCAL_PORT}      user: admin   password: ${PASS:-<run: make argocd-password>}
  MLflow (dev)      http://localhost:${MLFLOW_DEV_LOCAL_PORT}      (works once mlflow-dev is deployed)
  MLflow (staging)  http://localhost:${MLFLOW_STAGING_LOCAL_PORT}      (works once mlflow-staging is synced)

EOF

wait
