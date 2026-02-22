# Bun + pi.dev Container

This project provides a multi-stage container definition at `container/Containerfile` with:

- `bun` installed in a builder stage (`oven/bun:1`) and copied into a slim runtime
- `git` installed in runtime (`debian:bookworm-slim`)
- `tmux` installed in runtime (`debian:bookworm-slim`)
- `pi` installed globally (`@mariozechner/pi-coding-agent`)
- a configurable default working directory
- an entrypoint that launches `pi` inside a tmux session when running interactively

## Build (Podman)

Default working directory inside the container is `/project`.

```bash
podman build -f container/Containerfile -t bun-pi .
```

### Configure working directory at build time

Use `APP_DIR` to set a different default workdir:

```bash
podman build -f container/Containerfile --build-arg APP_DIR=/app -t bun-pi .
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

By default, it opens `/bin/sh` in the container.
It runs with `--userns=keep-id` and mounts the workspace as `/project:Z`.

Pass an explicit container command when needed:

```bash
./tapir.sh "$PWD" pi
./tapir.sh "$PWD" bun --version
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
```
