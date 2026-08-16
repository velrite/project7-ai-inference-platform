# Network Architecture

## VPC and subnet
A custom VPC, project7-vpc, was created rather than using GCP's
default network. One subnet, project7-subnet, in us-central1, with a
/20 primary range for nodes, a /16 secondary range for pods, and a
/20 secondary range for services. Private Google access is enabled on
the subnet.

## Routing and load balancing
The NGINX Ingress Controller provisions a GCP Network Load Balancer
automatically on install. This is the only external entry point into
the cluster - verified, since no other LoadBalancer-type Service
exists in this project.

## DNS
No custom DNS zone was configured. The ingress is reached by its
external IP directly. Not implemented: a domain name and managed
certificate were considered out of scope for this demonstration.

## Firewall and network policy
GKE's default firewall rules apply at the VPC level. Pod-level
segmentation is enforced separately through Kubernetes NetworkPolicy,
described below.

## East-west traffic (pod to pod)
Governed by a default-deny NetworkPolicy applied cluster-wide,
with one explicit allow rule permitting only pods labeled
access=granted to reach a target pod. This was tested live: a pod
without the label was blocked, a pod with the label succeeded. See
failure-modes.md for the real incident encountered while getting this
control to actually enforce.

## North-south traffic (external to cluster)
All external traffic passes through the NGINX Ingress, which enforces
a 5 requests-per-second rate limit per client IP and a 1MB request
body size limit. Both were tested live under real load - a concurrent
30-request burst produced a mix of HTTP 200 and HTTP 503 responses,
and a 2MB payload produced an HTTP 413 response.

## Public and private boundary
Only the NGINX Ingress Controller's load balancer IP is public.
Application pods, the Kubernetes API server, and platform tooling
(Kyverno, Argo CD) are not directly internet-reachable.
