# ArgoCD installed from the official Helm chart (deck slides 33-35).
# Managing ArgoCD itself with Terraform keeps the installation reproducible and
# reviewable, and identical across environments.

resource "helm_release" "argocd" {
  name             = "argocd"
  namespace        = "argocd"
  create_namespace = true

  repository = "https://argoproj.github.io/argo-helm"
  chart      = "argo-cd"
  version    = var.argocd_chart_version

  timeout         = 600
  wait            = true
  cleanup_on_fail = true

  values = [yamlencode({
    configs = {
      params = {
        # Serve plain HTTP so `kubectl port-forward` + http://localhost:8080 just works.
        # Demo only: put TLS in front of the server for anything real.
        "server.insecure" = true
      }
      cm = {
        # Poll Git every 30s (default is 2-3 minutes) so the demo feels responsive.
        "timeout.reconciliation"        = "30s"
        "timeout.reconciliation.jitter" = "5s"
      }
    }

    # Not needed for a local demo. Keeps the footprint small.
    dex           = { enabled = false }
    notifications = { enabled = false }
  })]
}
