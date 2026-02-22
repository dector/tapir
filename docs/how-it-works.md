# How tapir works

This document contains implementation details. End users should primarily use `tapir` / `tapir.sh`.

## High-level flow

1. `tapir.sh` parses flags (`+version`, `+tmux`, `+no-user-home`, `+install`).
2. It resolves workspace and image source (remote tag/SHA or local `+version=this`).
3. It prepares mounts/env for:
   - workspace (`/project` by default)
   - Bun install/cache
   - persistent `pi` state
4. It runs Podman with host UID/GID and executes `pi` (or provided command).

## Local vs remote image

- `+version=this` -> local build mode (`tapir:this` by default)
- otherwise -> remote image mode (`ghcr.io/<owner>/tapir:<version>` by default)

Local builds are rebuilt only when the computed build hash changes.

## Container internals

`container/Containerfile` is multi-stage:

- **builder** (`BUN_IMAGE`, default `docker.io/oven/bun:1.3.9`)
  - installs pinned `@mariozechner/pi-coding-agent@${PI_VERSION}`
  - prewarms with `pi --help`
- **runtime** (`RUNTIME_IMAGE`, default `docker.io/debian:bookworm-slim`)
  - installs runtime tools: `git`, `tmux`, `ripgrep`, `fd-find`, `jq`, `ca-certificates`
  - copies Bun + global packages + warmed cache from builder

### Runtime defaults

- Workdir: `/project` (build arg `APP_DIR`)
- Entrypoint: `/usr/local/bin/container-entrypoint.sh`
- Default command: `pi --help`

### Runtime env

- `BUN_INSTALL=/opt/bun/.bun`
- `BUN_INSTALL_CACHE_DIR=/opt/bun/.bun/install/cache`
- `BUN_RUNTIME_TRANSPILER_CACHE_PATH=/opt/bun/.bun/install/cache/@t@`

Additional setup includes:

- `node -> bun` symlink
- `fd -> fdfind` symlink
- `pi` symlink to installed CLI entrypoint

## Entrypoint behavior

`container/entrypoint.sh`:

- if no args -> runs `pi --help`
- if command is `pi` and `TAPIR_TMUX=1` with TTY -> wraps with `tmux new-session -A -s pi`
- otherwise executes command directly

## Embedded build metadata

Build metadata is injected via build args and exposed as:

- OCI labels:
  - `org.opencontainers.image.revision`
  - `org.opencontainers.image.version`
  - `org.opencontainers.image.created`
- Runtime artifacts:
  - `/usr/local/share/tapir/build-info`
  - `tapir-version` command

## Build context minimization

`.dockerignore` allows only container build files into context, keeping builds lightweight.

## Validation

```bash
podman build -f container/Containerfile -t tapir .
podman run --rm tapir bun --version
podman run --rm tapir git --version
podman run --rm tapir pi --version
podman run --rm tapir tapir-version
```
