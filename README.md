# ArgoCD + Helm GitOps demo: minikube + a public GitHub repo

A small, fully local demo for the lecture **"MLOps CI/CD, Topic 7: ArgoCD for Helm deployments"**.
ArgoCD runs in a local minikube cluster and deploys an MLflow Helm chart to `dev` and `staging`
straight from **your own public GitHub repository**. No Git server, no secrets manager, no credentials:
fork or create the repo, run `make up`, present.

The step-by-step presentation script is in **[DEMO.md](DEMO.md)**. This file covers setup.

> There is also a heavier, fully offline variant (Gitea inside the cluster, Vault, a private repo). This one trades
> that for a much shorter setup. It needs internet access while you demo, because ArgoCD reads the repo from GitHub.

## How it fits together

```
 your laptop                                       GitHub (public repo, your fork)
 +-----------------------------+   git push       +------------------------------+
 | this folder, a clone of it  | ---------------> | branch "demo"                |
 | edit gitops/envs/*/values   |                  |   gitops/charts/mlflow/...   |
 +-----------------------------+                  |   gitops/envs/{dev,staging}  |
                                                  +--------------+---------------+
 minikube (profile "argocd-demo")                                 ^ ArgoCD polls every 30 s
 +--------------------------------------------------------------+ | (anonymous HTTPS read)
 | ns argocd           ArgoCD  --------------------------------------+
 |                       |-- Application mlflow-dev      (auto-sync + self-heal)
 |                       '-- Application mlflow-staging  (manual sync)
 | ns mlflow-dev       MLflow   (created by ArgoCD)
 | ns mlflow-staging   MLflow   (created by ArgoCD)
 +--------------------------------------------------------------+
```

| Lecture topic (slides) | Where it lives |
|---|---|
| GitOps principles, Git as source of truth (8-11) | the GitHub repo, the `gitops/` folder |
| ArgoCD architecture and flow (22-26) | `kubectl get pods -n argocd`, the UI |
| Repo structure, config separate from code (29-31) | `gitops/charts/` vs `gitops/envs/` |
| Deploying ArgoCD with Terraform (33-35) | `terraform/` |
| First service through an `Application` (38-40) | `bootstrap/mlflow-dev.yaml`, `scripts/03-bootstrap.sh` |
| Private repo access (36-37) | not needed here, see [Going private](#going-private-optional) |

## Prerequisites

| Tool | Notes |
|---|---|
| Docker (or another minikube driver) | must be running |
| minikube 1.32+, kubectl | |
| Terraform 1.5+ | the Helm provider needs no separate Helm install |
| git, curl, bash, make | macOS and Linux out of the box. On Windows use **WSL2** |
| A GitHub account | with a way to `git push` (a credential helper, `gh auth login`, or an SSH key) |

**Resources:** 4 CPUs and 6 GB RAM for minikube (the defaults), about 8 GB free disk. The first run downloads roughly
1.5 GB (minikube's own base image and Kubernetes preload, plus about 0.5 GB for ArgoCD, Redis and MLflow). With less memory: `MINIKUBE_CPUS=2 MINIKUBE_MEMORY=4096 make cluster`. All images are multi-arch,
so Apple Silicon works. Internet access is needed during the demo.

## One-time setup: put this project on GitHub

ArgoCD reads the repository **from GitHub**, so the project has to live in a public repo you can push to.

```bash
unzip argocd-minikube-github-demo.zip && cd argocd-minikube-github-demo
git init -b main && git add -A && git commit -m "ArgoCD demo"

# create a PUBLIC repo and push. With the GitHub CLI:
gh repo create argocd-minikube-github-demo --public --source=. --push
# ...or create an empty public repo on github.com, then:
#   git remote add origin https://github.com/<you>/argocd-minikube-github-demo.git && git push -u origin main

# a dedicated branch keeps the demo commits away from main
git switch -c demo && git push -u origin demo
```

If you share the repo with students, they simply **fork it** and clone their fork. Nothing in the project mentions a
user name: the scripts read the repository URL from your clone's `origin` remote and the branch you have checked out.

## Quick start

```bash
make up          # about 5-10 minutes the first time
make forward     # in a SECOND terminal: opens the UIs on localhost, leave it running
```

`make up` first prints which repository and branch ArgoCD will watch, so you can confirm it is the right one.

| What | URL | Login |
|---|---|---|
| ArgoCD | http://localhost:8080 | `admin` / run `make argocd-password` (also printed by `make forward`) |
| MLflow dev | http://localhost:5001 | none |
| MLflow staging | http://localhost:5002 | none (available after you press Sync, see DEMO.md) |

Expected end state: `mlflow-dev` is **Synced / Healthy**, `mlflow-staging` is **OutOfSync** on purpose
(manual sync, it is a demo scene).

Run `make help` for all targets. Optionally run `make prepull` right after `make cluster` to download the MLflow
image ahead of time (useful on slow Wi-Fi).

## What each step does

| # | Command | What happens |
|---|---|---|
| 0 | `make prereqs` | Checks the tools and shows the detected repository and branch |
| 1 | `make cluster` | `minikube start` with profile `argocd-demo` |
| 2 | `make argocd` | Terraform (`terraform/`) installs **ArgoCD** from its Helm chart |
| 3 | `make bootstrap` | Checks that GitHub is readable without credentials and that your branch is pushed, then applies two `Application` objects (`mlflow-dev`, `mlflow-staging`) pointing at your repo and branch |

From step 3 on, **the cluster is changed only by pushing to GitHub**.

## Project layout

```
.
├── Makefile                  entry point (make help)
├── README.md                 this file
├── DEMO.md                   presentation script with timings
├── gitops/                   what ArgoCD deploys from
│   ├── charts/mlflow/          the Helm chart (Deployment, Service)
│   └── envs/{dev,staging}/     per-environment values (the files you edit during the demo)
├── bootstrap/                the two Application manifests (templates, filled in by step 3)
├── terraform/                installs ArgoCD (Helm provider)
├── scripts/                  numbered setup scripts and helpers (all read scripts/env.sh)
└── work/                     created at runtime: rendered manifests, recorded start point (git-ignored)
```

Settings (ports, cluster size, profile name) live in `scripts/env.sh` and can be overridden with environment
variables, for example `ARGOCD_LOCAL_PORT=9090 make forward`. To watch a different repo or branch than your clone's:
`REPO_URL=https://github.com/<you>/<repo>.git GIT_BRANCH=demo make bootstrap`.

## Between demo runs

| Goal | Command |
|---|---|
| Put the demo branch (and so the cluster) back to the starting commit | `make reset-demo` |
| See what is running | `make status` |
| Stop the cluster but keep it | `minikube stop -p argocd-demo` (resume with `minikube start -p argocd-demo`) |
| Delete everything local | `make destroy` (your GitHub repo is not touched) |

`make reset-demo` **force-pushes** your demo branch back to the commit it had at `make bootstrap`. For that reason it
refuses to run on `main` or `master`, with uncommitted changes, or on any other branch than the recorded one.

## Going private (optional)

The lecture's slides 36-37 cover how ArgoCD reads a **private** repository. With a private repo, ArgoCD needs a
credential. The simplest local version is a Kubernetes Secret with the label ArgoCD looks for. Use a fine-grained
GitHub token with read-only access to that one repository:

```bash
kubectl --context argocd-demo -n argocd create secret generic github-repo-creds \
  --from-literal=type=git \
  --from-literal=url=https://github.com/<you>/<repo> \
  --from-literal=username=<you> \
  --from-literal=password=<read-only token>
kubectl --context argocd-demo -n argocd label secret github-repo-creds argocd.argoproj.io/secret-type=repo-creds

SKIP_REPO_CHECK=1 make bootstrap     # the anonymous-read check would fail on a private repo
```

Never commit the token. For the "token lives in Vault and Terraform creates the Secret" version from the slides, use
the Gitea-based demo project.

## Troubleshooting

**`make bootstrap` says it cannot read the repository anonymously.** The repo is private, the URL is wrong, or a typo
in the remote. Open the URL in a private browser window. If it loads, ArgoCD can read it too.

**`make bootstrap` says the branch is not on GitHub yet.** Run `git push -u origin <branch>`.

**An Application shows `ComparisonError`, `repository not found` or `authentication required`.** ArgoCD cannot
read the repo: it is private (see above), or the `repoURL` or branch is wrong. Check the rendered file
`work/mlflow-dev.yaml`, then `kubectl --context argocd-demo -n argocd describe application mlflow-dev`.
After fixing the URL run `make bootstrap` again.

**Your push does not show up in ArgoCD.** ArgoCD polls GitHub every 30 seconds in this setup. Press **Refresh**
on the application to look immediately. Also confirm you pushed the branch the Application watches
(`git status -sb` and `cat work/demo-branch`).

**The cluster cannot reach GitHub (corporate proxy or VPN).** Pods in minikube use your machine's network. Try off
the VPN, or configure a proxy for minikube (`MINIKUBE_EXTRA_ARGS="--docker-env HTTPS_PROXY=..."`).

**An image fails with `ErrImagePull` or a rate-limit message.** The Argo CD chart pulls Redis from Amazon ECR Public
and other images come from Quay and GHCR, all with anonymous limits. Wait a few minutes and the pod retries by itself.
`make prepull` helps for the MLflow image.

**`terraform apply` times out while installing ArgoCD.** Almost always slow image pulls. Run `make argocd` again,
Helm continues where it stopped.

**`port-forward` errors or "address already in use".** Another process uses 8080, 5001 or 5002. Change the port,
for example `ARGOCD_LOCAL_PORT=9090 make forward`. `make forward` restarts dropped forwards by itself.

**minikube cannot start.** Make sure Docker is running and has enough memory, or choose another driver with
`MINIKUBE_EXTRA_ARGS="--driver=hyperkit"` (any driver minikube supports works).

**Windows.** Use WSL2 (Ubuntu) and run everything, including Docker integration, inside it.

## Notes (this is a lecture demo)

- The repository is **public** and the demo commits ("dev: two replicas", reverts) are public too. Use a dedicated
  branch or a throwaway repo, and never put secrets in it.
- ArgoCD serves plain HTTP (`server.insecure=true`) because the UI is reached through a local port-forward.
- MLflow uses SQLite on an `emptyDir` volume, so data is lost when a pod restarts. A real setup would use PostgreSQL
  and object storage.
