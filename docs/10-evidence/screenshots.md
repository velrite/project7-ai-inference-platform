# Evidence and Screenshots

Every claim in this documentation set is either backed by a screenshot
below, or explicitly marked as not yet verified. Each box states
exactly what to capture and what it proves - fill these in directly
from terminal output or the GCP/GitHub console.

===================================================================
SCREENSHOT 1: GKE cluster live
WHAT TO CAPTURE: terminal output of kubectl get nodes -o wide, showing
both node pools with STATUS Ready
PROVES: the cluster and system node pool are real, running
infrastructure, not just Terraform files
===================================================================

===================================================================
SCREENSHOT 2: Terraform plan, clean apply
WHAT TO CAPTURE: terminal output of a terraform apply showing
"Apply complete" with the resource count matching what was reviewed
in the preceding plan
PROVES: infrastructure changes are reviewed before being applied, not
blindly auto-approved
===================================================================

===================================================================
SCREENSHOT 3: NetworkPolicy proof - before and after
WHAT TO CAPTURE: terminal output showing the allowed-client and
blocked-client curl test results after enforcement was fixed - one
HTTP 200, one timeout or connection refused
PROVES: default-deny network segmentation is actually enforced, not
just defined
===================================================================

===================================================================
SCREENSHOT 4: Secret Manager Workload Identity proof
WHAT TO CAPTURE: terminal output showing the bound pod successfully
printing the secret value, and the unbound pod's PERMISSION_DENIED
error, side by side or in sequence
PROVES: secret access is identity-scoped, not open to any pod in the
cluster
===================================================================

===================================================================
SCREENSHOT 5: CI pipeline, fully green
WHAT TO CAPTURE: GitHub Actions run summary showing every step passed
- checkout, auth, build, push, Trivy scan, SBOM, Cosign sign - with
green checkmarks throughout
PROVES: a complete, working software supply chain, not isolated
working pieces
===================================================================

===================================================================
SCREENSHOT 6: Trivy CRITICAL finding and exception
WHAT TO CAPTURE: the Trivy scan output showing CVE-2025-37797 as the
single CRITICAL finding, paired with the .trivyignore file content
PROVES: vulnerabilities are found and consciously triaged, not
silently ignored or hidden
===================================================================

===================================================================
SCREENSHOT 7: Kyverno signature enforcement - reject and accept
WHAT TO CAPTURE: terminal output showing the admission webhook denial
for the unsigned/nonexistent image reference, and the successful pod
creation for the signed image, in sequence
PROVES: only cryptographically signed images can run on this cluster
===================================================================

===================================================================
SCREENSHOT 8: Ingress rate limiting under burst
WHAT TO CAPTURE: terminal output of the 30-request concurrent burst
test, showing the mix of HTTP 200 and HTTP 503 responses
PROVES: the rate limit is a real, load-bearing control, not just a
configured annotation
===================================================================

===================================================================
SCREENSHOT 9: Ingress request size limit
WHAT TO CAPTURE: terminal output showing the 2MB payload test
returning HTTP 413
PROVES: oversized-payload abuse is rejected before reaching the
application
===================================================================

===================================================================
SCREENSHOT 10: Model integrity verification - all three cases
WHAT TO CAPTURE: terminal output of the three test runs - correct
checksum passing, wrong checksum failing, tampered file detected
PROVES: model artifact integrity is actively checked, not assumed
===================================================================

===================================================================
SCREENSHOT 11: GitOps auto-prune proof
WHAT TO CAPTURE: terminal output of argocd app get before and after
removing the CPU-fallback manifests from Git, showing the pruned
status and the matching commit hash in Sync Status
PROVES: Git is the actual source of truth for cluster state, verified
by observed behavior, not by description
===================================================================

===================================================================
SCREENSHOT 12: GPU quota blocker, direct evidence
WHAT TO CAPTURE: the MIG error log output showing the exact text
"Quota 'GPUS_ALL_REGIONS' exceeded. Limit: 0.0 globally."
PROVES: the GPU blocker is a specific, named, external constraint,
not a vague or unexplained failure
===================================================================
