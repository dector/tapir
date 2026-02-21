# Bun + pi.dev Container

This project provides a multi-stage `Containerfile` with:

- `bun` installed in a builder stage (`oven/bun:1`) and copied into a slim runtime
- `git` installed in runtime (`debian:bookworm-slim`)
- `pi` installed globally (`@mariozechner/pi-coding-agent`)
- a configurable default working directory

## Build (Podman)

Default working directory inside the container is `/project`.

```bash
podman build -f Containerfile -t bun-pi .
```

### Configure working directory at build time

Use `APP_DIR` to set a different default workdir:

```bash
podman build -f Containerfile --build-arg APP_DIR=/app -t bun-pi .
```

## Run

Mount your current project and start in the container workdir:

```bash
podman run --rm -it \
  -v "$PWD":/project \
  -w /project \
  bun-pi pi
```

### Easy workdir configuration

Set two variables once and reuse them:

```bash
HOST_DIR="$PWD"
CONTAINER_DIR="/project"

podman run --rm -it \
  -v "${HOST_DIR}:${CONTAINER_DIR}:Z" \
  -w "${CONTAINER_DIR}" \
  bun-pi pi
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
podman run --rm bun-pi pi --version
```
