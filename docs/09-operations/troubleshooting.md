# Troubleshooting

## General approach
Check terraform state list before assuming a resource does or does not
exist. Check kubectl describe pod and its Events section before
assuming a scheduling failure's cause. Check the lowest-level
available log source - direct Managed Instance Group error logs, not
just GKE's summary status - when a higher-level layer reports success
but the real-world result contradicts it.

## Cloud Shell specific
Cloud Shell is ephemeral. Terraform and Cosign were both found missing
in fresh sessions during this project, despite having been installed
earlier - both were added to ~/.customize_environment so they persist
across session resets going forward.

## Common command-line pitfall encountered in this project
A stale bash command-location cache can report a just-installed binary
as not found. Running hash -r clears this and was the actual fix on
two separate occasions during this build, rather than a reinstall
being necessary.
