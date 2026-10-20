#!/usr/bin/env bash
# Create the ArgoCD Applications for dev and staging, pointing at YOUR GitHub fork,
# and wait until dev is deployed.
set -euo pipefail
# shellcheck source=env.sh
source "$(dirname "${BASH_SOURCE[0]}")/env.sh"

detect_repo
log "Repository: ${REPO_URL}"
log "Branch:     ${GIT_BRANCH}"

# ArgoCD runs in the cluster and reads the repo from GitHub without credentials, so
# the repository must be public and the branch must already exist on GitHub.
# (GIT_TERMINAL_PROMPT=0 turns a private repo into a clear error instead of a login prompt.)
# For a private repository set SKIP_REPO_CHECK=1 and create the credentials Secret
# yourself (README, "Going private").
if [[ "${SKIP_REPO_CHECK:-0}" == "1" ]]; then
  warn "SKIP_REPO_CHECK=1: not checking that ArgoCD can read the repository."
else
  if ! GIT_TERMINAL_PROMPT=0 git ls-remote --exit-code --heads "$REPO_URL" "$GIT_BRANCH" >/dev/null 2>&1; then
    if GIT_TERMINAL_PROMPT=0 git ls-remote --exit-code "$REPO_URL" >/dev/null 2>&1; then
      die "Branch '${GIT_BRANCH}' is not on GitHub yet. Push it first: git push -u origin ${GIT_BRANCH}"
    fi
    die "Cannot read ${REPO_URL} anonymously. Is the repository public and the URL correct? (Private repo: see README, Going private, then run SKIP_REPO_CHECK=1 make bootstrap.)"
  fi

  # Warn if what ArgoCD will see on GitHub differs from your local checkout.
  if [[ "$(git -C "$ROOT_DIR" symbolic-ref --short -q HEAD || true)" == "$GIT_BRANCH" ]]; then
    remote_sha="$(git ls-remote --heads "$REPO_URL" "$GIT_BRANCH" | cut -f1)"
    local_sha="$(git -C "$ROOT_DIR" rev-parse HEAD)"
    [[ "$remote_sha" == "$local_sha" ]] \
      || warn "Local HEAD differs from GitHub (${GIT_BRANCH}). ArgoCD only sees what is pushed: git push"
  fi
fi

mkdir -p "$WORK_DIR"
for app in mlflow-dev mlflow-staging; do
  sed -e "s|__REPO_URL__|${REPO_URL}|g" -e "s|__BRANCH__|${GIT_BRANCH}|g" \
    "$ROOT_DIR/bootstrap/${app}.yaml" > "$WORK_DIR/${app}.yaml"
done

log "Applying the Applications (rendered copies: ${WORK_DIR}/mlflow-*.yaml)"
k apply -f "$WORK_DIR/mlflow-dev.yaml" -f "$WORK_DIR/mlflow-staging.yaml"

# Remember the starting point so `make reset-demo` can return to it.
git -C "$ROOT_DIR" rev-parse HEAD > "$WORK_DIR/demo-start-sha"
printf '%s\n' "$GIT_BRANCH" > "$WORK_DIR/demo-branch"

log "Waiting for mlflow-dev to become Healthy (the first image pull can take several minutes)"
k -n argocd wait --for=jsonpath='{.status.health.status}'=Healthy application/mlflow-dev --timeout=900s \
  || { warn "mlflow-dev is not healthy yet. Check: kubectl --context ${KUBE_CONTEXT} -n argocd describe application mlflow-dev"; exit 1; }

log "Applications:"
k -n argocd get applications
log "Expected: mlflow-dev is Synced/Healthy; mlflow-staging is OutOfSync (manual sync, press Sync in the UI)."
