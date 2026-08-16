# CI/CD Pipeline

## Pipeline stages, in order
A push to the master branch triggers the workflow. The runner
authenticates to GCP through Workload Identity Federation, using no
static key. Docker is configured to push to Artifact Registry. The
container image is built from app/Dockerfile. The built image is
pushed to Artifact Registry by its exact digest. Trivy scans the
pushed image, failing the pipeline on any CRITICAL-severity finding
not explicitly excepted in .trivyignore. Syft generates a
SPDX-JSON Software Bill of Materials, uploaded as a pipeline artifact.
Cosign installs, then signs the pushed image using a private key held
only in GitHub Actions Secrets, keyed to the image's exact digest.

## Why the image is pushed before scanning
Trivy and Cosign both need a reachable, addressable image reference to
act on - a purely local Docker build has no digest that can be
referenced by a registry-based signature or scan record. This was
discovered directly: an earlier version of this pipeline attempted to
sign a locally-built, never-pushed image and failed with an
authentication error against Docker Hub, because the bare image name
had no real registry location. The corrected order - build, push,
then scan and sign - reflects that finding.

## Quality and security gates
Trivy's exit code causes the workflow to fail on any un-excepted
CRITICAL finding. This is a real gate, not advisory - it was proven to
work when the pipeline correctly failed on CVE-2025-37797 before that
finding was reviewed and formally excepted.

## Artifact management
Both the SBOM and the built image itself are retained: the image in
Artifact Registry, tagged by commit SHA and referenced by digest; the
SBOM as a downloadable GitHub Actions artifact attached to each run.

## Not implemented
Multi-environment promotion (dev, staging, production) is not
implemented - this project has a single environment. Canary and
blue-green deployment strategies are not implemented, since the
inference workload is intentionally single-replica by design.
