# Bun + pi.dev Container

This project provides a multi-stage container definition at `container/Containerfile` with:

- `bun` installed in a builder stage (default `oven/bun:1.3.9`) and copied into a slim runtime
- `git` installed in runtime (default `debian:bookworm-slim`)
- `tmux` installed in runtime (default `debian:bookworm-slim`)
- `pi` installed globally as a pinned package version (default `@mariozechner/pi-coding-agent@0.54.0`)
- familiar CLI tools preinstalled for agent workflows: `rg` (ripgrep), `fd`, and `jq`
- bun and global packages stored in `/usr/local/bun` so tools run with `--userns=keep-id`
- a configurable default working directory
- an entrypoint that launches `pi` inside a tmux session when running interactively

## Build (Podman)

Default working directory inside the container is `/project`.

```bash
podman build -f container/Containerfile -t bun-pi .
```

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
  -t bun-pi .
```

## Run

Mount your current project and start `pi` in the container workdir:

```bash
podman run --rm -it \
  -v "$PWD":/project \
  -w /project \
  bun-pi \
  pi
```

### Easy workdir configuration

Set two variables once and reuse them:

```bash
HOST_DIR="$PWD"
CONTAINER_DIR="/project"

podman run --rm -it \
  -v "${HOST_DIR}:${CONTAINER_DIR}:Z" \
  -w "${CONTAINER_DIR}" \
  bun-pi \
  pi
```

### Helper script

Use the included script to mount a workspace directory into `/project`:

```bash
./tapir.sh "$PWD"
```

The script rebuilds the `bun-pi` image when `container/Containerfile`, `container/entrypoint.sh`, or configured build args change.
By default, it runs `pi` in the container.
In an interactive terminal, the container entrypoint starts or reattaches a `tmux` session named `pi`.
It runs as your host UID/GID (`--userns=keep-id` + `--user`) and mounts the workspace as `/project:Z` by default.

Pass an explicit container command when needed:

```bash
./tapir.sh "$PWD" pi
./tapir.sh "$PWD" bun --version
```

You can override build pins used by `tapir.sh` via env vars:

```bash
TAPIR_BUN_IMAGE=docker.io/oven/bun:1.3.9 \
TAPIR_RUNTIME_IMAGE=docker.io/debian:bookworm-slim \
TAPIR_PI_VERSION=0.54.0 \
TAPIR_APP_DIR=/project \
./tapir.sh "$PWD"
```

## Pass API keys or environment variables

Example (OpenAI):

```bash
podman run --rm -it \
  -v "$PWD":/project \
  -w /project \
  -e OPENAI_API_KEY \
  bun-pi pi
```

## Quick checks

```bash
podman run --rm bun-pi bun --version
podman run --rm bun-pi git --version
podman run --rm bun-pi tmux -V
podman run --rm bun-pi pi --version
podman run --rm bun-pi rg --version
podman run --rm bun-pi fd --version
podman run --rm bun-pi jq --version
```
