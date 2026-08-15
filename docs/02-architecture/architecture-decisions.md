# Architecture Decision Records

## ADR-001: GKE Standard (zonal) over Autopilot or regional cluster

**Context**
Needed explicit control over node pools for GPU-specific scheduling (taints, tolerations, machine-type pairing) — Autopilot abstracts node management away, which conflicts with the requirement to demonstrate GPU-aware scheduling explicitly.

**Options considered**
- GKE Autopilot
- GKE Standard, regional (3-zone control plane)
- GKE Standard, zonal (single-zone control plane)

**Decision**
GKE Standard, zonal.

**Rationale**
Standard gives full node-pool control, required for the GPU taint/toleration demonstration. Zonal (not regional) matches the explicit non-goal of multi-zone HA — paying for a 3-zone control plane to then claim no HA was tested would be dishonest about what was actually built.

**Trade-offs**
No control-plane redundancy. Acceptable: this is a demonstration platform with a stated non-goal of multi-zone resilience, not a claim of production HA.

**Consequences**
Every reliability claim in this project is scoped to single-zone behavior only, and is stated as such throughout.

---

## ADR-002: Custom VPC over GCP default network

**Context**
GCP provisions a default VPC with permissive auto-created firewall rules in every new project.

**Options considered**
- Default VPC
- Custom VPC, explicit subnets and secondary ranges

**Decision**
Custom VPC (`project7-vpc`), explicit /20 node range, /16 pod range, /20 service range.

**Rationale**
A custom VPC means every subnet and route exists because it was deliberately defined — required for the project to credibly demonstrate and test network isolation (default-deny NetworkPolicy) later.

**Trade-offs**
More upfront Terraform to write. No functional downside found.

---

## ADR-003: GKE's NetworkPolicy addon (Calico) enabled post-creation

**Context**
NetworkPolicy objects were applied and appeared to succeed, but a live test proved traffic was not actually being blocked.

**What happened (real incident, not hypothetical)**
Enabling `network_policy.enabled = true` alone was insufficient — GKE also requires `addons_config.network_policy_config.disabled = false`. Even after both were set correctly, the `calico-node` DaemonSet showed `0/0/0` scheduled, because it uses a node selector (`projectcalico.org/ds-ready=true`) that GKE does not retroactively apply to nodes that existed before the addon was enabled.

**Decision**
Manually labeled existing nodes with `projectcalico.org/ds-ready=true` to unblock the DaemonSet, then re-verified with live traffic tests.

**Rationale**
This was the fastest correct fix. The alternative (full cluster recreation with the addon enabled from creation) was available but unnecessary once the specific gap was identified.

**Consequences / lesson**
"No error on `kubectl apply` is not proof a security control is active." This project subsequently tested every other admission/network control (Kyverno, ingress limits) with explicit positive AND negative live tests, specifically because this incident proved that discipline was necessary, not optional.

Full incident record: `docs/07-reliability/failure-modes.md`.

---

## ADR-004: Workload Identity Federation over service-account JSON keys for CI

**Context**
CI needed to authenticate to GCP to push images and (indirectly) let Kyverno pull them for signature verification.

**What happened (real incident)**
Attempted the conventional path first: create a JSON key for a dedicated CI service account. This failed:
```
FAILED_PRECONDITION: Key creation is not allowed on this service account
```
— the org enforces `constraints/iam.disableServiceAccountKeyCreation`.

**Options considered**
- Request an org-policy exception to allow key creation
- Workload Identity Federation (GitHub OIDC → GCP, no key ever exists)

**Decision**
Workload Identity Federation.

**Rationale**
The org policy blocking key creation is itself a real-world best practice (static, non-expiring credentials are a common breach vector). Rather than fighting it, building the more secure pattern the policy was nudging toward was both the correct engineering call and directly aligned with this project's own stated preference for Workload Identity over static keys.

**Trade-offs**
More setup: a Workload Identity Pool, a Provider trusting GitHub's OIDC issuer, and an `attribute_condition` restricting it to this exact repo. No static key ever exists on disk or in GitHub Secrets as a result.

---

## ADR-005: System node pool sized up twice, disk sized down then back up

**Context**
The always-on system pool needed to host Calico, Kyverno, Argo CD, and the NGINX Ingress controller simultaneously.

**What happened (real incident sequence)**
1. `e2-small` (2 vCPU / 2GB): Calico's second Typha replica stuck `Pending` — `Insufficient cpu`.
2. Resized to `e2-medium`, but disk-size resize hit the `SSD-TOTAL-GB` regional quota (250GB limit) during the rolling node replacement, because two 100GB-disk nodes existed simultaneously.
3. Reduced `disk_size_gb` to 30GB to fit under the SSD quota during replacement — this then caused `DiskPressure` evictions once the large `vllm/vllm-openai` base image was pulled.
4. Settled on `e2-standard-2` with `disk_size_gb: 50` — enough headroom for platform tooling plus large image pulls, without breaching the SSD quota even during a rolling replace.

**Decision**
`e2-standard-2`, 50GB disk, `min_node_count: 1`, `max_node_count: 8`.

**Rationale**
Each of the three intermediate configurations was individually reasonable given the information available at the time; each was proven wrong by a live scheduling or eviction failure, not by guesswork. The final configuration is the one that survived real load (Calico + Kyverno + Argo CD + NGINX + image pulls, all coexisting).

**Consequences**
This sequence is documented in full in `failure-modes.md` as it is a real, representative example of capacity planning by measurement rather than by estimate.

---

## ADR-006: GPU deployment blocked by a project/account-level quota (open issue)

**Context**
The project requires a GPU-backed inference workload. GKE, IAM, Terraform, and the vLLM deployment manifests are all complete and correct — the blocker is external to this project's engineering.

**What was tried, in order, each with direct evidence**
1. NVIDIA L4 (original choice) — individual quota was 0, later resolved to non-zero — still blocked.
2. NVIDIA T4 — same pattern.
3. NVIDIA P100 — ruled out: hardware not available in the target zone (`us-central1-a`) at all; confirmed via `gcloud compute accelerator-types list`.
4. NVIDIA V100 — individual quota confirmed non-zero (limit: 1.0), zone stock confirmed present in all `us-central1` zones, node pool created successfully in Terraform. Node provisioning still failed.
5. Direct Compute Engine instance creation (bypassing GKE entirely, to get an unfiltered error) — failed with:
   ```
   Quota 'GPUS_ALL_REGIONS' exceeded. Limit: 0.0 globally.
   ```
6. Region variation (5 regions tested directly) — `GPUS_ALL_REGIONS` is a project-level quota, not regional; confirmed via `gcloud compute project-info describe`, same 0.0 result regardless of region.
7. Fresh GCP project, same (already-verified) billing account — identical `GPUS_ALL_REGIONS: 0.0` result, confirmed via direct MIG error log inspection. This ruled out "bad project history" as a cause.

**Root cause (confirmed, not inferred)**
`GPUS_ALL_REGIONS` is a single, project/account-level quota that overrides every individual per-GPU-type quota. It is tied to the Google account or billing identity, not to any specific project, region, or GPU type. The self-service quota-increase form explicitly rejects requests for this specific quota ("you are not eligible for a quota increase at this time"), and GCP billing support confirmed by email that quota increases of this kind fall outside their scope and must go through manual review.

**Decision**
Escalated to Google Cloud Support with the exact quota name and MIG error text (the most specific, actionable evidence available), and continued all GPU-independent engineering work in parallel rather than blocking the entire project on a pending external approval.

**Consequences**
Every downstream capability that requires a live GPU pod (inference proof, TTFT/TPOT measurement, autoscaling under real load, cold-start timing, load testing to saturation, cost-per-inference calculation) is explicitly marked «Blocked — see ADR-006» rather than estimated or faked. See `failure-modes.md` for the full chronological incident record.
