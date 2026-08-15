# Requirements

## Functional requirements

| Requirement | Status |
|---|---|
| Deploy an open-source LLM behind an HTTP API | ✅ Verified in configuration (`k8s/vllm-deployment.yaml`); **not yet verified live** — see [ADR-006](../02-architecture/architecture-decisions.md#adr-006) |
| Infrastructure fully reproducible from code | ✅ Verified — 100% Terraform, zero manual console provisioning of core resources |
| CI/CD with vulnerability scanning | ✅ Verified — Trivy scan, CRITICAL-severity gate, documented exception process |
| Software Bill of Materials per build | ✅ Verified — Syft, SPDX-JSON, uploaded as CI artifact |
| Cryptographic image signing | ✅ Verified — Cosign, keyless-auth CI (Workload Identity Federation) |
| Admission-time signature enforcement | ✅ Verified — Kyverno ClusterPolicy, live-tested (unsigned image rejected, signed image accepted) |
| Model artifact integrity verification | ✅ Verified — checksum script, tested pass/fail/tamper cases |
| Network segmentation | ✅ Verified — default-deny NetworkPolicy, live-tested |
| Secrets never stored in plaintext or Git | ✅ Verified — GCP Secret Manager + Workload Identity, live-tested (bound pod succeeds, unbound pod denied) |
| Ingress-level abuse protection | ✅ Verified — rate limiting (proven under concurrent burst), request size limits (proven with oversized payload) |
| GitOps-managed deployment | ✅ Verified — Argo CD, live-tested auto-prune on manifest removal |

## Non-functional requirements

| Attribute | Target | Actual |
|---|---|---|
| Availability | Not applicable — single-replica demo workload, no SLA target set | «Not measured» |
| Latency (TTFT, TPOT) | Spec called for measurement under load | «Not measured — blocked, see ADR-006» |
| Throughput | Spec called for saturation-point testing | «Not measured — blocked, see ADR-006» |
| Cost ceiling | $300 total (GCP free-trial credit) | Actual spend documented in [docs/08-finops/cost-model.md](../08-finops/cost-model.md) |
| Recovery from pod failure | Spec called for live kill-and-observe test | «Not yet performed — planned once GPU workload is live» |
| Deployment reproducibility | Full environment recreatable from Git alone | ✅ Verified — every apply in this project traces to a Terraform file in version control |

Where a target could not be measured, that is stated plainly rather than
estimated or assumed.
