#!/usr/bin/env bash
# shellcheck shell=bash disable=SC2034
#
# Central settings and helpers for every script in this folder.
# This file is SOURCED by the other scripts; you normally never run it directly.
# Override any setting by exporting it first, e.g.:  MINIKUBE_CPUS=2 make cluster

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
export ROOT_DIR
export WORK_DIR="${WORK_DIR:-$ROOT_DIR/work}"

# --- minikube ---------------------------------------------------------------
export MINIKUBE_PROFILE="${MINIKUBE_PROFILE:-argocd-demo}"
export MINIKUBE_CPUS="${MINIKUBE_CPUS:-4}"
export MINIKUBE_MEMORY="${MINIKUBE_MEMORY:-6144}"   # MB
export MINIKUBE_EXTRA_ARGS="${MINIKUBE_EXTRA_ARGS:-}"
# minikube names the kubectl context after the profile.
export KUBE_CONTEXT="${KUBE_CONTEXT:-$MINIKUBE_PROFILE}"

# --- local ports for the UIs --------------------------------------------------
export ARGOCD_LOCAL_PORT="${ARGOCD_LOCAL_PORT:-8080}"
export MLFLOW_DEV_LOCAL_PORT="${MLFLOW_DEV_LOCAL_PORT:-5001}"
export MLFLOW_STAGING_LOCAL_PORT="${MLFLOW_STAGING_LOCAL_PORT:-5002}"

# --- Terraform variables (picked up automatically as TF_VAR_*) ------------------
export TF_VAR_kube_context="$KUBE_CONTEXT"

# --- helpers --------------------------------------------------------------------
log()  { printf '\033[1;34m==>\033[0m %s\n' "$*"; }
warn() { printf '\033[1;33m!!\033[0m  %s\n' "$*" >&2; }
die()  { printf '\033[1;31mxx\033[0m  %s\n' "$*" >&2; exit 1; }

# kubectl pinned to the demo cluster, so it never touches another context by accident.
k() { kubectl --context "$KUBE_CONTEXT" "$@"; }

# detect_repo: work out which GitHub repository and branch ArgoCD should watch.
#
# By default it reads them from YOUR clone: the URL of the "origin" remote and the
# branch you currently have checked out. Override with REPO_URL and/or GIT_BRANCH.
# Sets REPO_URL (https, no credentials, ends with .git) and GIT_BRANCH.
detect_repo() {
  local origin
  if [[ -z "${REPO_URL:-}" ]]; then
    origin="$(git -C "$ROOT_DIR" remote get-url origin 2>/dev/null)" \
      || die "No 'origin' remote found. Clone your GitHub fork first, or set REPO_URL=https://github.com/<you>/<repo>.git"
    case "$origin" in
      git@github.com:*)          REPO_URL="https://github.com/${origin#git@github.com:}" ;;
      ssh://git@github.com/*)    REPO_URL="https://github.com/${origin#ssh://git@github.com/}" ;;
      https://*@github.com/*)    REPO_URL="https://github.com/${origin#*@github.com/}" ;;  # drop embedded credentials
      https://github.com/*)      REPO_URL="$origin" ;;
      *) die "Origin '${origin}' is not a github.com URL. Set REPO_URL=https://github.com/<you>/<repo>.git" ;;
    esac
    REPO_URL="${REPO_URL%.git}.git"
  fi
  if [[ -z "${GIT_BRANCH:-}" ]]; then
    GIT_BRANCH="$(git -C "$ROOT_DIR" symbolic-ref --short -q HEAD)" \
      || die "Detached HEAD. Check out a branch (for example: git switch -c demo) or set GIT_BRANCH."
  fi
  export REPO_URL GIT_BRANCH
}
