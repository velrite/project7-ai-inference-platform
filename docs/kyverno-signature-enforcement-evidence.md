# Kyverno Admission Enforcement - Signature Verification

## Setup
- Kyverno ClusterPolicy `require-signed-images` enforces Cosign
  signature verification on all images matching
  `us-central1-docker.pkg.dev/velrite-tf-test/project7-inference/*`
- Kyverno bound to a GCP identity via Workload Identity to allow
  pulling images for verification (initial gap found and fixed -
  IAM granted to node SA does not flow to individual pods; each
  pod needs its own explicit Workload Identity binding)

## Proven behavior
- A pod referencing a real, CI-signed image digest: ACCEPTED
- A pod referencing a non-existent/unsigned tag: REJECTED by
  Kyverno admission webhook

## Lesson (consistent with NetworkPolicy incident earlier)
Initial test attempts produced misleading results due to test
data errors (invalid image references, digests that were
themselves signed by later successful CI runs) rather than
policy failures. Real verification required using a guaranteed
non-existent reference to eliminate ambiguity.
