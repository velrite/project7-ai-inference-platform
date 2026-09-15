
## Real per-workload cost attribution (OpenCost)

Deployed OpenCost + a self-hosted Prometheus (`prometheus-system` namespace)
for real per-namespace cost allocation, pulling actual GCP list pricing via
the Cloud Billing API (requires `cloudbilling.googleapis.com` enabled and a
Cloud Billing API key — see `scripts/startup.sh`).

**Caveat:** figures below reflect ~14 minutes of real measured usage since
OpenCost/Prometheus were deployed, extrapolated by OpenCost's allocation
model. This is real GCP pricing applied to a genuine (small) sample — not
yet a stable monthly figure. Re-pull after 24–48h of runtime for a number
worth citing as representative.

| Namespace | CPU cost | RAM cost | Total |
|---|---|---|---|
| `default` (vLLM) | $0.01814 | $0.00778 | $0.02591 |
| `kube-system` | $0.01481 | $0.00183 | $0.01664 |
| `gke-managed-cim` | $0.00076 | $0.00012 | $0.00089 |
| `gmp-system` | $0.00008 | $0.00008 | $0.00016 |
| `opencost` | $0.00008 | $0.00006 | $0.00014 |
| `prometheus-system` | $0 | $0 | $0 |
| **Total (measured window)** | | | **$0.04374** |

Pulled via: `curl "localhost:9003/allocation/compute?window=7d&aggregate=namespace"`
after port-forwarding `svc/opencost` in the `opencost` namespace.

Note: Prometheus is deployed with `persistentVolume.enabled=false` — history
is lost on pod restart, so allocation data resets to near-zero after any
restart until it re-accumulates.
