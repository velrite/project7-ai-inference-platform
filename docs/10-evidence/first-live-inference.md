# First Live Inference - Proven

## Request
POST /v1/chat/completions to vllm-inference-cpu-svc, model
Qwen/Qwen2.5-1.5B-Instruct, prompt "Say hello in exactly 5 words.",
max_tokens 50.

## Response
HTTP 200 OK. Response content: "Hello there!"
finish_reason: stop. completion_tokens: 4. prompt_tokens: 17.
Server fingerprint: vllm-0.21.1-c1d47678.

## What this proves
A real, live, end-to-end inference request was served by this
platform - not simulated, not mocked. The full path worked: ingress
routing not yet in front of this service, but Service to Pod routing,
model loading, and generation all confirmed real and working.

## Path to get here (real engineering, not a first-try success)
The official vllm/vllm-openai image has no CPU support and crashes
immediately with a device-detection error on CPU-only nodes. The
correct image is the officially published CPU-specific build at
public.ecr.aws/q9t5s3a7/vllm-cpu-release-repo. Even with the correct
image, the container deadlocked indefinitely during model warmup due
to a shared-memory IPC issue in vLLM's V1 multiprocess executor,
confirmed via near-zero CPU usage despite a Running status - a true
positive-look, false-progress state. Setting
VLLM_ENABLE_V1_MULTIPROCESSING=0 to force single-process mode resolved
the deadlock. A correctly sized /dev/shm volume (default Kubernetes
64MB is insufficient) and --enforce-eager (skipping slow torch.compile
warmup) were both required alongside this fix.

## Note on positioning
This inference is running on a dedicated CPU node pool
(e2-standard-4), not the originally planned GPU (V100) pool, due to
the external GCP quota constraint documented in ADR-006. The platform
was engineered for GPU inference; CPU serving is a deliberate,
documented adaptation that validates the full serving stack end to
end, pending GPU quota resolution.
