# Architecture Decision Records

## ADR-001: GKE Standard, zonal, over Autopilot or a regional cluster

Context: needed explicit control over node pools for GPU-specific
scheduling (taints, tolerations, machine-type pairing). Autopilot
abstracts node management away, which conflicts with the requirement
to demonstrate GPU-aware scheduling explicitly.

Options considered: GKE Autopilot, GKE Standard regional (3-zone
control plane), GKE Standard zonal (single-zone control plane).

Decision: GKE Standard, zonal.

Rationale: Standard gives full node-pool control, required for the
GPU taint and toleration demonstration. Zonal, not regional, matches
the explicit non-goal of multi-zone HA. Paying for a 3-zone control
plane and then claiming no HA was tested would misrepresent what was
actually built.

Trade-offs: no control-plane redundancy. Acceptable, since this is a
demonstration platform with a stated non-goal of multi-zone
resilience, not a claim of production HA.

Consequences: every reliability claim in this project is scoped to
single-zone behavior only, and is stated as such throughout.

## ADR-002: Custom VPC over the GCP default network

Context: GCP provisions a default VPC with permissive auto-created
firewall rules in every new project.

Options considered: default VPC, or a custom VPC with explicit
subnets and secondary ranges.

Decision: custom VPC named project7-vpc, with an explicit /20 node
range, /16 pod range, and /20 service range.

Rationale: a custom VPC means every subnet and route exists because
it was deliberately defined, which was required to credibly
demonstrate and later test network isolation through a default-deny
NetworkPolicy.

Trade-offs: more upfront Terraform to write. No functional downside
found.

## ADR-003: GKE's NetworkPolicy addon enabled after cluster creation

Context: NetworkPolicy objects were applied and appeared to succeed,
but a live test proved traffic was not actually being blocked.

What happened: enabling network_policy.enabled alone was
insufficient - GKE also requires
addons_config.network_policy_config.disabled set to false. Even after
both were set correctly, the calico-node DaemonSet showed 0 of 0
scheduled, because it uses a node selector
(projectcalico.org/ds-ready=true) that GKE does not retroactively
apply to nodes that existed before the addon was enabled.

Decision: manually labeled the existing nodes with
projectcalico.org/ds-ready=true to unblock the DaemonSet, then
re-verified with live traffic tests.

Rationale: this was the fastest correct fix. The alternative, a full
cluster recreation with the addon enabled from creation, was
available but unnecessary once the specific gap was identified.

Consequences and lesson: no error on kubectl apply is not proof a
security control is active. Every other admission and network control
in this project was subsequently tested with explicit positive and
negative live tests, specifically because this incident proved that
discipline was necessary, not optional. Full incident record is in
failure-modes.md.

## ADR-004: Workload Identity Federation over service-account JSON keys for CI

Context: CI needed to authenticate to GCP to push images and,
indirectly, to let Kyverno pull them for signature verification.

What happened: the conventional path was attempted first - creating a
JSON key for a dedicated CI service account. This failed with
FAILED_PRECONDITION: key creation is not allowed on this service
account, because the org enforces
constraints/iam.disableServiceAccountKeyCreation.

Options considered: requesting an org-policy exception to allow key
creation, or Workload Identity Federation, where GitHub's OIDC token
authenticates directly and no key ever exists.

Decision: Workload Identity Federation.

Rationale: the org policy blocking key creation is itself a real-world
best practice, since static, non-expiring credentials are a common
breach vector. Building the more secure pattern the policy was nudging
toward was both the correct engineering call and directly aligned with
this project's own stated preference for Workload Identity over
static keys.

Trade-offs: more setup - a Workload Identity Pool, a Provider trusting
GitHub's OIDC issuer, and an attribute condition restricting it to
this exact repository. No static key ever exists on disk or in GitHub
Secrets as a result.

## ADR-005: System node pool sized up twice, disk sized down then back up

Context: the always-on system pool needed to host Calico, Kyverno,
Argo CD, and the NGINX Ingress controller simultaneously.

What happened, in sequence: an e2-small node (2 vCPU, 2GB) left
Calico's second Typha replica stuck Pending with Insufficient cpu.
Resizing to e2-medium then hit the SSD-TOTAL-GB regional quota during
the rolling node replacement, because two 100GB-disk nodes existed at
once. Reducing disk_size_gb to 30GB fit under that quota during
replacement, but then caused DiskPressure evictions once the large
vllm/vllm-openai base image was pulled. The final configuration,
e2-standard-2 with a 50GB disk, gave enough headroom for platform
tooling plus large image pulls without breaching the SSD quota even
during a rolling replace.

Decision: e2-standard-2, 50GB disk, min_node_count 1, max_node_count 8.

Rationale: each intermediate configuration was individually reasonable
given the information available at the time, and each was proven
wrong by a live scheduling or eviction failure, not by guesswork. The
final configuration is the one that survived real load - Calico,
Kyverno, Argo CD, NGINX, and image pulls all coexisting.

Consequences: this sequence is documented in full in
failure-modes.md, as a representative example of capacity planning by
measurement rather than by estimate.

## ADR-006: GPU deployment blocked by a project or account-level quota

Context: the project requires a GPU-backed inference workload. GKE,
IAM, Terraform, and the vLLM deployment manifests are all complete and
correct - the blocker is external to this project's engineering.

What was tried, in order, each with direct evidence: NVIDIA L4 quota
was initially zero, later resolved to non-zero, still blocked. NVIDIA
T4 followed the same pattern. NVIDIA P100 was ruled out because the
hardware is not available in the target zone at all, confirmed via
gcloud compute accelerator-types list. NVIDIA V100 had individual
quota confirmed non-zero, zone stock confirmed present in every
us-central1 zone, and the node pool was created successfully in
Terraform - node provisioning still failed. A direct Compute Engine
instance creation, bypassing GKE entirely to get an unfiltered error,
failed with: Quota GPUS_ALL_REGIONS exceeded, limit 0.0 globally.
Region variation across five regions confirmed GPUS_ALL_REGIONS is a
project-level quota, not a regional one, via gcloud compute
project-info describe, with the same 0.0 result regardless of region.
A fresh GCP project under the same already-verified billing account
produced the identical GPUS_ALL_REGIONS 0.0 result, confirmed via
direct MIG error log inspection, ruling out bad project history as a
cause.

Root cause, confirmed rather than inferred: GPUS_ALL_REGIONS is a
single project or account-level quota that overrides every individual
per-GPU-type quota. It is tied to the Google account or billing
identity, not to any specific project, region, or GPU type. The
self-service quota-increase form explicitly rejects requests for this
specific quota, and GCP billing support confirmed by email that
increases of this kind fall outside their scope and must go through
manual review.

Decision: escalated to Google Cloud Support with the exact quota name
and MIG error text, and continued all GPU-independent engineering
work in parallel rather than blocking the entire project on a pending
external approval.

Consequences: every downstream capability that requires a live GPU
pod - inference proof, TTFT and TPOT measurement, autoscaling under
real load, cold-start timing, load testing to saturation, and
cost-per-inference calculation - is explicitly marked as blocked by
this ADR rather than estimated or faked. The full chronological
incident record is in failure-modes.md.
