# Documented Security Exceptions

## CVE-2025-37777 - linux-libc-dev (CRITICAL)

**Status:** Accepted risk, documented exception.

**Finding:** Use-after-free vulnerability in the Linux kernel's ksmbd
(in-kernel SMB server) component, present in linux-libc-dev package
version 5.15.0-187.197 shipped in the vllm/vllm-openai base image.

**Why accepted:**
- linux-libc-dev provides kernel headers only, not a running kernel
- The vulnerable component (ksmbd, an SMB file-sharing server) is not
  used, started, or exposed by this application in any way
- vLLM's inference server has no SMB functionality or dependency
- No fixed version is currently available upstream for this base image
- Attack surface: none - the vulnerable code path is never executed

**Review cadence:** Re-evaluated on every base image update. If a
fixed version becomes available, upgrade at that time.

**Decision made by:** Olamide (Velrite), as part of Project 7 CI/CD
security pipeline hardening, August 2026.

## CVE-2026-53398, CVE-2026-64535, CVE-2026-64564 - linux-libc-dev (CRITICAL)

**Status:** Accepted risk, documented exception.

**Finding:** Three kernel vulnerabilities in linux-libc-dev, affecting
NFSD (SECINFO_NO_NAME decode), nvmet-tcp (use-after-free on digest
mismatch), and sctp (ASCONF transport handling) - none in this
package's actual runtime kernel, only its headers.

**Why accepted:**
- linux-libc-dev provides kernel headers only, not a running kernel
- This workload (vLLM HTTP inference server) does not use NFS,
  NVMe-over-TCP, or SCTP in any capacity
- No fixed version currently available for this base image
- Same category and same justification as CVE-2025-37797, documented
  earlier in this same file

**Review cadence:** Re-evaluated on every base image update, consistent
with the existing policy for this project.
