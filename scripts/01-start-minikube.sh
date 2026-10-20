#!/usr/bin/env bash
# Start (or resume) the local minikube cluster.
set -euo pipefail
# shellcheck source=env.sh
source "$(dirname "${BASH_SOURCE[0]}")/env.sh"

log "Starting minikube profile '${MINIKUBE_PROFILE}' (${MINIKUBE_CPUS} CPUs, ${MINIKUBE_MEMORY} MB)"
# MINIKUBE_EXTRA_ARGS is intentionally unquoted so several flags can be passed.
# shellcheck disable=SC2086
minikube start -p "$MINIKUBE_PROFILE" \
  --cpus="$MINIKUBE_CPUS" \
  --memory="$MINIKUBE_MEMORY" \
  $MINIKUBE_EXTRA_ARGS

log "Cluster is up:"
k get nodes
