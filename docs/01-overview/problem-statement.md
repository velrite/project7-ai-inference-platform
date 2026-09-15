# Problem Statement

## The problem
Running an open-source LLM once, on a laptop or a single cloud VM, is
easy. Running it as a *production service* — reachable safely, observable
under load, resilient to failure, cost-controlled, and provably secure
against a compromised image or model artifact — is a materially different
engineering problem. Most "I deployed an LLM" portfolio projects stop at
the first sentence and never touch the second.

## Why this matters
Inference workloads are expensive (GPU time), security-sensitive (a
compromised container or tampered model weights is a real supply-chain
risk), and bursty (idle most of the time, spiky under real traffic).
A platform that only proves "it responds to curl" has not demonstrated
any of the actual operating constraints a production inference service
faces.

## Engineering constraints specific to this project
- **Budget**: built entirely on a GCP free-trial-derived account with a
  hard $300 ceiling — every infrastructure decision had to account for
  cost, not just capability.
- **GPU access is not guaranteed**: covered in detail in
  [ADR-006](../02-architecture/architecture-decisions.md#adr-006).
  This constraint materially shaped what could be verified live versus
  what remains verified-in-configuration-only.
- **Solo operation**: one engineer, acting as both implementer and
  reviewer, which is reflected honestly in the incident write-ups —
  every mistake found was found by the same person who made it, through
  deliberate verification, not by a second reviewer.

## Why this platform exists
To demonstrate — with evidence, not claims — that the author can design,
build, secure, and operate the infrastructure layer around an AI model,
independent of the model itself. See
[goals-and-non-goals.md](goals-and-non-goals.md) for the explicit scope
boundary.
