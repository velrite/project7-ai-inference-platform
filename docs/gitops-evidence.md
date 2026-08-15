# GitOps (Argo CD) - Proven Working

## Setup
- Argo CD installed on the cluster
- Application `project7-inference` tracks the `k8s/` path in
  github.com/velrite/project7-ai-inference-platform
- Sync policy: automated, self-heal, auto-prune

## Proven behavior
1. Removed abandoned CPU-fallback manifests from Git
   (git rm + commit + push)
2. Argo CD detected the change and pruned the corresponding
   Deployment from the live cluster automatically - no manual
   kubectl commands needed
3. Confirmed via `argocd app get`: Sync Status matched the exact
   git commit hash (b3a43f9)
4. Confirmed via `kubectl get deployments`: pruned resource was
   genuinely gone from the cluster, not just reported as gone

## What this proves
Git is the actual source of truth for cluster state. A change
to the repo alone - no direct kubectl apply - resulted in a
real, verified change to the running cluster.
