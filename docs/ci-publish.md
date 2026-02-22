# CI publish workflow

Workflow file: `.github/workflows/publish-image.yml`

## Trigger

- Push to `trunk`
- Manual run via `workflow_dispatch`

## What it publishes

Image name base:

- `ghcr.io/<owner>/tapir`

Tags:

- `latest`
- `<short-commit-sha>`

## Build metadata wiring

Workflow computes:

- lowercase owner
- short SHA (`${GITHUB_SHA::7}`)
- UTC build timestamp
- source URL (`https://github.com/<owner>/<repo>`)

It passes build args:

- `TAPIR_VCS_REF=${{ github.sha }}`
- `TAPIR_BUILD_VERSION=<short-sha>`
- `TAPIR_BUILD_DATE=<utc-iso-8601>`

This keeps `tapir-version` and `/usr/local/share/tapir/build-info` aligned with CI artifacts.

## OCI labels set by workflow

- `org.opencontainers.image.title`
- `org.opencontainers.image.description`
- `org.opencontainers.image.source`
- `org.opencontainers.image.url`
- `org.opencontainers.image.revision`
- `org.opencontainers.image.created`
