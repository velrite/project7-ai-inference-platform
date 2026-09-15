# Full Environment Recovery Runbook — project7-ai-inference-platform

Use after a full teardown, `terraform destroy`, or Cloud Shell/cluster loss.
`scripts/startup.sh` automates all of this. `scripts/teardown.sh` is plan-only —
it never destroys anything unattended.

**Quick path:**
- `bash scripts/teardown.sh` — generates a destroy plan, prints it, prints the
  exact `terraform apply` command to run yourself.
- `bash scripts/startup.sh` — rebuilds everything with plan-then-confirm gates,
  automatic WIF soft-delete recovery, hard context checks before every
  `kubectl` step, and a real end-to-end health check at the end.

## What startup.sh does, in order

1. Confirms gcloud project context, pulls latest repo.
2. `terraform init` and `plan`. Logs (does not block on) the GPU pool —
   confirmed safe: `autoscaling` with `maxNodeCount: 1`, creates in seconds,
   costs nothing while idle at 0 nodes. Intentionally left in place so
   flipping CPU to GPU later is a scale-up, not new Terraform.
3. Requires typing `apply` to confirm before `terraform apply` runs.
4. If `google_iam_workload_identity_pool.github` or its provider come back
   `state: DELETED` on GCP (soft-delete after a prior destroy), the script
   undeletes and imports them into state automatically instead of failing
   with a 409.
5. Gets kubectl credentials, hard-checks context equals
   `gke_velrite-tf-test_us-central1-a_project7-cluster`, aborts on mismatch.
   **Re-checks this again immediately before the kubectl apply block** —
   this project shares a GCP account with `atlas-dev` and a Forge cluster,
   and a stale context previously caused resources to be created on Forge
   by mistake.
6. Applies Workload Identity KSA, network policies (default-deny, then
   explicit allow).
7. **Checkpoint — signed-image admission policy.** Still unresolved: whether
   `require-signed-images.yaml`'s scope would block the vLLM pod, which
   uses an unsigned public image. Script pauses and asks before applying it.
8. Deploys vLLM (CPU), service, ingress, observability.
9. Waits for the pod to reach `1/1 Ready` (model load takes several minutes
   on CPU — expected).
10. Port-forwards and curls `/v1/models` automatically, reports pass/fail —
    a real end-to-end check, not just a healthy-looking pod.

## Known gotchas (all hit for real, not hypothetical)

- Cloud Shell disconnects mid-apply do not mean the operation failed —
  Terraform/GKE operations run server-side. Reconnect and check real state
  (`gcloud container operations list`) before re-running anything.
- Workload Identity Pools/Providers are **soft-deleted**, not hard-deleted.
  Re-creating one with the same ID after a `terraform destroy` throws
  `409 Requested entity already exists`. Fix is undelete + `terraform import`,
  not retrying the apply. Now automated in `startup.sh`.
- This account has multiple clusters (`atlas-dev`, Forge, `project7-cluster`).
  A stale `kubectl` context silently applies manifests to the wrong cluster
  with no error — always verify `kubectl config current-context` immediately
  before, not just at the start of a session.
- The `vllm-deployment-cpu.yaml` `nodeSelector: {pool: cpu-inference}` fails
  on Autopilot clusters (GKE Warden rejects custom node-selector keys) but
  works fine on project7's standard cluster. If this error reappears, it
  means the context is pointed at an Autopilot cluster, not that the
  manifest is broken.
- **Open, unverified:** `require-signed-images.yaml`'s exact scope — still
  needs a one-time manual read before this checkpoint can be automated.
- **Open, unverified:** README claims GitOps deployment as a proven control;
  no Argo CD manifests found in this repo as of last search.

## Verifying the recovery actually worked

Automated by `startup.sh` at the end: `curl localhost:8000/v1/models` and a
`/v1/completions` request must return a real generated token, not just a
`1/1 Running` pod.
