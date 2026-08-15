# Goals and Non-Goals

## Goals
- Prove infrastructure-as-code discipline: no manually-clicked resources
  for anything core (network, cluster, IAM, registry).
- Prove a real, working software supply chain: scan → SBOM → sign →
  admission-enforced verification, with live positive/negative tests for
  every control, not just "the YAML exists."
- Prove GitOps as the actual deployment mechanism, not a description of
  one.
- Prove methodical incident diagnosis: every failure encountered during
  the build is documented with root cause, not just "then it worked."
- Operate under a real, hard cost constraint and document every dollar
  decision.

## Non-goals (explicit, matching original project scope)
- Model training, fine-tuning, or distributed training
- Multi-GPU or multi-node inference
- MIG / GPU partitioning
- Multi-region or multi-zone high availability
- A general-purpose MLOps or feature-store platform
- Model quality evaluation — the deployment gate proves the platform can
  *serve* a model safely, not that the model is scientifically good

## Scope boundary, stated plainly
This is a **platform engineering and DevSecOps demonstration**, not an
ML research project and not a claim of production-grade high
availability. Every control that is claimed to work has a live test
behind it in this documentation set. Anything without a live test is
labeled «Not verified» or «Blocked», not silently assumed.
