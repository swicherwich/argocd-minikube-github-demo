#!/usr/bin/env bash
# OPTIONAL: pre-pull the MLflow image into minikube before the demo, so the first
# deploy does not depend on conference Wi-Fi. Run it any time after `make cluster`.
set -euo pipefail
# shellcheck source=env.sh
source "$(dirname "${BASH_SOURCE[0]}")/env.sh"

tag="$(sed -n 's/^appVersion: *"\{0,1\}\([^"]*\)"\{0,1\} *$/\1/p' "$ROOT_DIR/gitops/charts/mlflow/Chart.yaml")"
[[ -n "$tag" ]] || die "Could not read appVersion from Chart.yaml"
image="ghcr.io/mlflow/mlflow:${tag}"

log "Pulling ${image} into minikube profile '${MINIKUBE_PROFILE}'"
minikube -p "$MINIKUBE_PROFILE" image pull "$image"
log "Done."
