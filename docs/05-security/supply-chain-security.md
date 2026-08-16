# Supply Chain Security

## Image scanning
Trivy scans every built image for CRITICAL and HIGH severity CVEs
across OS packages and libraries. The pipeline is configured to fail
only on CRITICAL, a deliberate and documented policy choice given the
vLLM base image's very large dependency tree - narrowing to CRITICAL
only, rather than disabling scanning or ignoring findings, is recorded
as an explicit trade-off, not a silent weakening.

## Documented exceptions
One CRITICAL finding, CVE-2025-37797 in linux-libc-dev, is formally
excepted via .trivyignore, with the justification recorded in
docs/security-exceptions.md: the vulnerable component, ksmbd, an
in-kernel SMB server, is never used, started, or exposed by this
inference workload.

## Software Bill of Materials
Syft generates a full SPDX-JSON SBOM for every build, uploaded as a
pipeline artifact. This allows a future CVE disclosure to be checked
against a specific build's exact dependency list without re-scanning.

## Signed artifacts
Every pushed image is signed with Cosign, using an ECDSA keypair, keyed
to the image's exact content digest rather than a mutable tag.

## Enforcement at deploy time
A Kyverno ClusterPolicy requires a valid Cosign signature, checked
against the project's public key, before any pod referencing an image
in this project's Artifact Registry path can be admitted to the
cluster. Proven live with both a rejected unsigned reference and an
accepted signed one.

## Model artifact integrity
Handled separately from container security, since a signed container
says nothing about the integrity of model weights fetched at runtime.
A dedicated SHA-256 checksum verification script was written and
tested with three real cases: a correct checksum passing, a wrong
checksum failing, and a tampered file being detected and rejected.
