#!/usr/bin/env bash
# Remove everything local: the minikube cluster, Terraform state and rendered files.
# Your GitHub repository and branch are left untouched.
set -euo pipefail
# shellcheck source=env.sh
source "$(dirname "${BASH_SOURCE[0]}")/env.sh"

log "Deleting minikube profile '${MINIKUBE_PROFILE}'"
minikube delete -p "$MINIKUBE_PROFILE" || true

log "Removing local Terraform state and rendered files"
rm -f "$ROOT_DIR"/terraform/terraform.tfstate "$ROOT_DIR"/terraform/terraform.tfstate.backup
rm -rf "$WORK_DIR"

log "Clean. Run 'make up' to build the demo again from scratch."
