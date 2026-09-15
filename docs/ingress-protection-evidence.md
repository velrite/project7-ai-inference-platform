# Ingress Protection - Proven Controls

## Rate Limiting (5 req/s per client IP)

Sequential requests (15, one at a time) did NOT trigger the limit -
NGINX rate limiting uses a token-bucket/sliding-window algorithm,
not a hard per-request counter, so normal sequential curl calls
arrive too slowly to exceed the threshold.

A true concurrent burst (30 simultaneous requests) DID trigger it:
- 26 requests: HTTP 200
- 4 requests: HTTP 503 (rate limited)

This confirms the control activates under genuine burst load, which
is the actual threat model for an inference API (a client hammering
the endpoint), not steady low-rate traffic.

## Request Size Limit (1MB max body)

Single test: 2MB payload sent via POST.
Result: HTTP 413 (Payload Too Large) - immediate, clean rejection.

## Lesson
Same principle as the NetworkPolicy incident: a security control must
be tested under conditions that actually resemble the real threat,
not just "does it respond." A weak test (sequential, low-rate) would
have given a false sense of confidence that rate limiting wasn't
working, when it actually was - just not exercised correctly.
