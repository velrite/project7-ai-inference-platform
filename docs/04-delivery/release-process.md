# Release Process

## Current process
Every commit to master that touches app/ triggers a full build, scan,
SBOM, and sign cycle - there is no separate tagged-release process
distinct from normal commits, appropriate for this project's single-
environment scope.

## Versioning
Images are identified by their Git commit SHA and, more precisely, by
their content digest. No semantic-versioning scheme is applied - not
required at this project's scope, and would be a reasonable addition
if this were extended toward multi-environment promotion.
