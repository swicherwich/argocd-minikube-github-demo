variable "kubeconfig_path" {
  description = "Path to the kubeconfig that contains the minikube context."
  type        = string
  default     = "~/.kube/config"
}

variable "kube_context" {
  description = "kubectl context of the minikube profile (minikube names it after the profile)."
  type        = string
  default     = "argocd-demo"
}

# Pinned so the demo behaves the same on every machine.
variable "argocd_chart_version" {
  description = "argo-cd Helm chart version (argo-helm repository)."
  type        = string
  default     = "10.10.5"
}
