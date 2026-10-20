SHELL := /bin/bash
.DEFAULT_GOAL := help

.PHONY: help up prereqs cluster argocd bootstrap prepull forward status argocd-password reset-demo destroy

help: ## Show this help
	@grep -E '^[a-zA-Z_-]+:.*## ' $(MAKEFILE_LIST) | awk 'BEGIN {FS = ":.*## "} {printf "  \033[1m%-16s\033[0m %s\n", $$1, $$2}'

up: prereqs cluster argocd bootstrap ## Build the whole demo from scratch (steps 0-3)
	@echo
	@echo "Demo is ready. Next: 'make forward' in a second terminal, then open http://localhost:8080"

prereqs: ## 0. Check tools and show which fork and branch ArgoCD will watch
	./scripts/00-check-prereqs.sh

cluster: ## 1. Start minikube
	./scripts/01-start-minikube.sh

argocd: ## 2. Terraform: install ArgoCD
	./scripts/02-install-argocd.sh

bootstrap: ## 3. Create the dev and staging Applications pointing at your GitHub fork
	./scripts/03-bootstrap.sh

prepull: ## Optional: pre-pull the MLflow image into minikube
	./scripts/prepull-images.sh

forward: ## Open port-forwards for the UIs (run in its own terminal, Ctrl+C to stop)
	./scripts/forward.sh

status: ## Show Applications, pods and app workloads
	./scripts/status.sh

argocd-password: ## Print the ArgoCD admin password
	@./scripts/argocd-password.sh

reset-demo: ## Reset your demo branch (and the cluster) to the starting point between runs
	./scripts/reset-demo.sh

destroy: ## Delete the cluster, Terraform state and rendered files
	./scripts/destroy.sh
