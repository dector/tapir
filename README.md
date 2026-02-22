# Bun + pi.dev Container

This project provides a multi-stage container definition at `container/Containerfile` with:

- `bun` installed in a builder stage (default `oven/bun:1.3.9`) and copied into a slim runtime
- `git` installed in runtime (default `debian:bookworm-slim`)
- `tmux` installed in runtime (default `debian:bookworm-slim`)
- `pi` installed globally as a pinned package version (default `@mariozechner/pi-coding-agent@0.54.0`)
- familiar CLI tools preinstalled for agent workflows: `rg` (ripgrep), `fd`, and `jq`
- bun and global packages stored in `/usr/local/bun` so tools run with `--userns=keep-id`
- a configurable default working directory
- an entrypoint that runs `pi` directly by default, with optional tmux session support

## Build (Podman)

Default working directory inside the container is `/project`.

```bash
podman build -f container/Containerfile -t tapir .
```

Build context is minimized via `.dockerignore` so only `container/Containerfile` and `container/entrypoint.sh` are sent to the builder.

### Configure pinned versions at build time

Defaults are pinned, but overridable with build args:

- `BUN_IMAGE` (default `docker.io/oven/bun:1.3.9`)
- `RUNTIME_IMAGE` (default `docker.io/debian:bookworm-slim`)
- `PI_VERSION` (default `0.54.0`)
- `APP_DIR` (default `/project`)

```bash
podman build -f container/Containerfile \
  --build-arg BUN_IMAGE=docker.io/oven/bun:1.3.9 \
  --build-arg RUNTIME_IMAGE=docker.io/debian:bookworm-slim \
  --build-arg PI_VERSION=0.54.0 \
  --build-arg APP_DIR=/project \
  -t tapir .
```

## Run

Mount your current project and start `pi` in the container workdir:

```bash
podman run --rm -it \
  -v "$PWD":/project \
  -w /project \
  tapir \
  pi
```

### Easy workdir configuration

Set two variables once and reuse them:

```bash
HOST_DIR="$PWD"
CONTAINER_DIR="/project"

podman run --rm -it \
  -v "${HOST_DIR}:${CONTAINER_DIR}:z" \
  -w "${CONTAINER_DIR}" \
  tapir \
  pi
```

### Helper script

Use the included script to mount a workspace directory into `/project`.

In an interactive terminal (and only when `CI` is not set), you can omit the workspace argument:

```bash
./tapir.sh
```

You will be prompted:

```text
Using workdir: <pwd> y/N:
```

The script continues only if you type `y`. Any other input exits.

In non-interactive terminals and CI, the workspace argument is still required:

```bash
./tapir.sh "$PWD"
```

The script rebuilds the `tapir` image when `container/Containerfile`, `container/entrypoint.sh`, or configured build args change.
By default, it runs `pi` in the container without tmux.
Use `+tmux` to opt in to starting or reattaching a `tmux` session named `pi` in interactive terminals.
It runs as your host UID/GID (`--userns=keep-id` + `--user`) and mounts the workspace as `/project:z` by default.

Pass an explicit container command when needed:

```bash
./tapir.sh "$PWD" pi
./tapir.sh "$PWD" bun --version
./tapir.sh +tmux
./tapir.sh +tmux "$PWD" pi
```

For direct `podman run`, set `-e TAPIR_TMUX=1` to enable tmux wrapping for `pi`.

You can override build pins used by `tapir.sh` via env vars:

```bash
TAPIR_BUN_IMAGE=docker.io/oven/bun:1.3.9 \
TAPIR_RUNTIME_IMAGE=docker.io/debian:bookworm-slim \
TAPIR_PI_VERSION=0.54.0 \
TAPIR_APP_DIR=/project \
./tapir.sh "$PWD"
```

## CI publish (GitHub Actions)

A workflow at `.github/workflows/publish-image.yml` builds and publishes the image to GHCR as:

- `ghcr.io/<owner>/tapir:<short-commit-sha>`

## Pass API keys or environment variables

Example (OpenAI):

```bash
podman run --rm -it \
  -v "$PWD":/project \
  -w /project \
  -e OPENAI_API_KEY \
  tapir pi
```

## Quick checks

```bash
podman run --rm tapir bun --version
podman run --rm tapir git --version
podman run --rm tapir tmux -V
podman run --rm tapir pi --version
podman run --rm tapir rg --version
podman run --rm tapir fd --version
podman run --rm tapir jq --version
```
