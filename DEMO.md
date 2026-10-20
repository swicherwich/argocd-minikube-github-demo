# Demo script: ArgoCD + Helm GitOps with a public GitHub repo (about 25 minutes)

Companion to the lecture deck "MLOps CI/CD, Topic 7: ArgoCD for Helm deployments". Setup is in [README.md](README.md).
Slide numbers below refer to that deck. All commands are run from the project root, which is also your Git clone.

## Story in one sentence

*Nobody touches the cluster. We push to GitHub, and ArgoCD makes the cluster match.*

## Before you start (do this 15 minutes earlier)

1. The project is in your public GitHub repo, on a branch such as `demo` (README, "One-time setup"), and that branch is
   checked out locally.
2. `make up` finished once and you have seen everything work. **Tip:** to run the "first Application" scene live,
   run only `make prereqs cluster argocd` plus `make prepull` beforehand, and `make bootstrap` on stage (scene 3).
3. Terminal 1 for commands, Terminal 2 running `make forward`. Increase the terminal font size.
4. Browser tabs: ArgoCD (http://localhost:8080, user `admin`, password from `make argocd-password`), your GitHub repo
   on the `demo` branch, and later MLflow (:5001, :5002).
5. Check you can commit and push without prompts popping up mid-demo: make a throwaway commit on the demo branch and
   `git push` it, then `make reset-demo`. (If you sign commits globally and it asks for a passphrase, either warm up
   your agent first or run `git config commit.gpgsign false` in this clone.)
6. Handy alias for the commands below (minikube already made `argocd-demo` your current context, so plain `kubectl` also works):
   ```bash
   alias k='kubectl --context argocd-demo'
   ```

## Timeline

| Min | Scene | Slides | What the audience sees |
|---|---|---|---|
| 0-4 | 1. The platform | 22-23, 33-35 | ArgoCD pods, the Terraform that installed them |
| 4-7 | 2. The Git repository | 29-31 | The repo on GitHub, its layout |
| 7-12 | 3. First Application | 38-40 | `make bootstrap`, apps appear in the UI |
| 12-16 | 4. Change through Git | 9, 26 | Edit, commit, push, auto-sync |
| 16-19 | 5. Drift and self-heal | 9 | `kubectl scale` gets reverted |
| 19-22 | 6. Staging: manual sync | 40 | OutOfSync, diff, Sync button |
| 22-25 | 7. Rollback | 9, 26 | `git revert`, cluster follows |
| 25+ | Wrap-up and questions | 11, 32, 42 | |

---

## Scene 1. The platform (slides 22-23, 33-35)

**Say:** ArgoCD is just a set of pods in the cluster. It pulls from Git, we do not push to it. And we installed it with
Terraform, so it is reproducible.

```bash
k get pods -n argocd
```

You should see `argocd-server` (API and UI), `argocd-repo-server` (reads Git and renders Helm),
`argocd-application-controller-0` (compares desired and live state, syncs), `argocd-redis` and
`argocd-applicationset-controller`. Dex/SSO and notifications are switched off for the demo (point at slide 23).

Open `terraform/argocd.tf` and show the `helm_release`: pinned chart version, `server.insecure` for plain HTTP, and
`timeout.reconciliation = 30s` so Git is polled every 30 seconds instead of every few minutes.

## Scene 2. The Git repository (slides 29-31)

Open your repo on GitHub (branch `demo`) and walk the tree under `gitops/`:

- `charts/mlflow/` is the Helm chart.
- `envs/dev/values.yaml` and `envs/staging/values.yaml` hold only the *differences* between environments.

**Say:** the repository is **public**, so ArgoCD reads it with no credentials at all. Slides 36-37 cover what changes for
a private repo: ArgoCD needs a credential stored as a Kubernetes Secret, ideally coming from a secrets manager
(README, "Going private").

**Say:** this repo holds *configuration only*, separate from application code (slide 31): changing a replica count needs
no application build, and access can be controlled separately.

## Scene 3. The first Application (slides 38-40)

**Say:** now we tell ArgoCD where to look. That is one `Application` object per environment, the only thing we apply by hand.

```bash
cat bootstrap/mlflow-dev.yaml
```

Explain `source` (repo, branch, folder, Helm values file), `destination` (this cluster, namespace `mlflow-dev`) and
`syncPolicy.automated` with `prune` and `selfHeal`. The repo URL and branch were filled in from your clone; the rendered
copy is `work/mlflow-dev.yaml`.

Create them live (if you held this step back in the pre-flight):

```bash
make bootstrap
```

Switch to the ArgoCD UI while it runs:

- `mlflow-dev` goes Progressing, then **Synced / Healthy**.
- `mlflow-staging` stays **OutOfSync / Missing** on purpose. It has no automated sync. Scene 6 uses it.

Check the workload as on slide 40:

```bash
k get all -n mlflow-dev
```

Open http://localhost:5001. The MLflow UI is running, deployed by ArgoCD from a Helm chart in Git.

## Scene 4. Change something through Git (slides 9, 26)

**Say:** we want two replicas in dev. We do not run `kubectl`. We edit a file and push.

```bash
sed -i.bak 's/replicaCount: 1/replicaCount: 2/' gitops/envs/dev/values.yaml && rm gitops/envs/dev/values.yaml.bak
git diff
git commit -am "dev: run two MLflow replicas"
git push
```

Watch the ArgoCD UI, tile **mlflow-dev**. Within about 30 seconds the app turns **OutOfSync**, then syncs by itself and a
second pod appears. (To skip the wait, press **Refresh** on the application.) In another terminal:

```bash
k get pods -n mlflow-dev -w
```

Show the commit on GitHub, then in ArgoCD open the application and its **History and rollback** tab: each deployment is
tied to a Git commit, "we can always tell who deployed what, when".

> Note for Q&A: with SQLite on a pod-local volume each replica has its own empty database. That is fine for showing the
> mechanism, it is not how you would run MLflow for real (use PostgreSQL and object storage).

## Scene 5. Drift and self-heal (slide 9, "observability")

**Say:** what if someone changes the cluster by hand? Git says 2 replicas.

```bash
k -n mlflow-dev scale deployment/mlflow --replicas=5
k get pods -n mlflow-dev -w
```

Within a few seconds ArgoCD notices the live state no longer matches Git (the app flashes **OutOfSync**) and `selfHeal`
puts it back to 2. **Say:** Git is the truth, manual changes do not survive. That is the answer to the question on slide 11:
without GitOps you get drift, undocumented hotfixes and no reproducibility.

## Scene 6. Staging with a manual gate (slide 40)

**Say:** dev is automatic, staging is not. Some teams want a human to approve promotion.

1. In the UI open **mlflow-staging**: it is **OutOfSync** because nothing is deployed there yet.
2. Click **Diff** (or **App Diff**) to show what would be created, then **Sync**, then **Synchronize**.
3. It becomes Synced / Healthy. Open http://localhost:5002.

Now make a change that waits for approval:

```bash
sed -i.bak 's/memory: 1Gi/memory: 1536Mi/' gitops/envs/staging/values.yaml && rm gitops/envs/staging/values.yaml.bak
git commit -am "staging: raise memory limit"
git push
```

After a refresh, **mlflow-staging** shows **OutOfSync** with a visible diff, and *nothing changes in the cluster* until a
person presses Sync. Compare with dev: same chart, same repo, only `syncPolicy` differs.

## Scene 7. Rollback is a git revert (slides 9, 26)

**Say:** the new setting is bad. We do not edit the cluster, we undo the commit.

```bash
git revert --no-edit HEAD      # reverts the staging change
git push
```

In the UI the staging diff disappears (the repo matches the cluster again). To revert dev, revert the replica commit too:

```bash
git log --oneline
git revert --no-edit <hash-of-the-dev-replicas-commit>
git push
```

The second pod in dev goes away. **Say:** rollback, audit trail and review all come from Git itself.

## Wrap-up and questions

Slide 11, *can you work effectively without GitOps and what are the risks?* Drift between Git and cluster, manual and
untracked changes, hard rollbacks, no single place to see which model version runs in which environment.

Slide 32, *why must Git be the only source of truth?* One audited place for changes, review through pull requests,
rollback by revert, a cluster that can be rebuilt from the repo (try `make destroy` then `make up` at home).

Slide 42, *mono-repo or app-per-folder?* Mono-repo is simple for small teams but scales badly (conflicts, one big blast
radius). App-per-repo gives isolation and delegation but multiplies repositories and Applications. App-per-folder is the
usual compromise, and it is what this demo uses (`gitops/charts/` plus `gitops/envs/`).

## Optional extras (if you have time)

**Pull-request flow.** Make the change on a new branch and open a pull request on GitHub, merge it, and show ArgoCD
reacting to the merge. This needs the Applications to watch the branch you merge into (use `REPO_URL=... GIT_BRANCH=main
make bootstrap` for that variant), and is the realistic team workflow: review first, deploy second.

**ArgoCD CLI.** If you have the `argocd` CLI: `argocd login localhost:8080 --plaintext --username admin --password "$(make -s argocd-password)"`,
then `argocd app list` and `argocd app diff mlflow-staging`.

## Reset and recovery

| Situation | Fix |
|---|---|
| Run the demo again | `make reset-demo` (the demo branch goes back to the starting commit and is force-pushed, ArgoCD follows within about 30 s). Press Sync on staging if you want it identical to dev |
| A push does not appear | Press **Refresh** on the application, polling is every 30 s. Check you pushed the watched branch |
| UI shows `ComparisonError` | See *Troubleshooting* in README.md (repo URL, branch, public or private) |
| Port-forward died | `make forward` retries by itself. If you closed it, start it again |
| Everything is confusing | `make status` shows applications, pods and workloads on one screen |
| Start from zero | `make destroy && make up` |
