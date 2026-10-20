#!/usr/bin/env bash
# Install ArgoCD with Terraform (terraform/).
set -euo pipefail
# shellcheck source=env.sh
source "$(dirname "${BASH_SOURCE[0]}")/env.sh"

TF_DIR="$ROOT_DIR/terraform"

log "terraform init"
terraform -chdir="$TF_DIR" init -input=false

log "terraform apply: installing ArgoCD. The first run pulls images, expect a few minutes."
terraform -chdir="$TF_DIR" apply -auto-approve -input=false

log "ArgoCD pods:"
k get pods -n argocd
