> [!WARNING]
> I use it but I might break this shit in process.
> Be careful.

# pi.dev Container

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

### Helper script (`tapir.sh`)

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

Flags:

- `+tmux` enables tmux wrapping (`session: pi`)
- `+version=<tag|sha|this>` chooses image source/version
  - `+version=latest` (default)
  - `+version=<short-sha-or-tag>` for pinned remote image
  - `+version=this` to build and use local `container/Containerfile`

Examples:

```bash
./tapir.sh +version=latest "$PWD"
./tapir.sh +version=abc1234 "$PWD" pi --version
./tapir.sh +version=this "$PWD"
./tapir.sh +tmux +version=this
```

Behavior summary:

- `+version=this`: local dev mode, rebuilds when `container/Containerfile`, `container/entrypoint.sh`, or build args change (hash label)
  - source root discovery priority: `TAPIR_SOURCE_DIR` → current working directory → workspace argument → script directory
  - set `TAPIR_SOURCE_DIR` explicitly when needed (for example, globally installed `tapir`)
- remote versions: pulls according to pull policy (below)
- always runs as host UID/GID (`--userns=keep-id` + `--user`) and mounts workspace as `/project:z`

#### Install as system-wide user command

```bash
install -Dm755 ./tapir.sh "$HOME/.local/bin/tapir"
```

Ensure `~/.local/bin` is in your `PATH`, then call:

```bash
tapir +version=latest
tapir +version=this
TAPIR_SOURCE_DIR="$HOME/src/tapir" tapir +version=this
```

#### Pull/cache policy for remote images

Env vars:

- `TAPIR_PULL_POLICY=auto|ttl|missing|always|never` (default: `auto`)
  - `auto` = `ttl` for `latest`, `missing` for pinned versions
- `TAPIR_PULL_TTL_SECONDS` (default: `600`)
- `TAPIR_PULL_ASYNC=1|0` (default: `1`, only relevant for stale `ttl` checks)
- `TAPIR_PULL_STATE_DIR` (default: `${XDG_CACHE_HOME:-$HOME/.cache}/tapir/pulls`)

Useful overrides:

```bash
TAPIR_PULL_POLICY=always ./tapir.sh +version=latest "$PWD"
TAPIR_PULL_POLICY=missing ./tapir.sh +version=abc1234 "$PWD"
TAPIR_PULL_POLICY=never ./tapir.sh +version=latest "$PWD"
```

#### Image naming and source overrides

- `TAPIR_REMOTE_IMAGE` (defaults to inferred `ghcr.io/<owner>/<repo>` if possible)
- `TAPIR_LOCAL_IMAGE` (default: `tapir:this`)
- `TAPIR_SOURCE_DIR` (explicit source repo root used by `+version=this`)

Build-pin overrides used for local (`+version=this`) builds:

```bash
TAPIR_BUN_IMAGE=docker.io/oven/bun:1.3.9 \
TAPIR_RUNTIME_IMAGE=docker.io/debian:bookworm-slim \
TAPIR_PI_VERSION=0.54.0 \
TAPIR_APP_DIR=/project \
./tapir.sh +version=this "$PWD"
```

## CI publish (GitHub Actions)

A workflow at `.github/workflows/publish-image.yml` builds and publishes the image to GHCR as:

- `ghcr.io/<owner>/tapir:latest`
- `ghcr.io/<owner>/tapir:<short-commit-sha>`

It also sets OCI image labels (`org.opencontainers.image.*`) for traceability.

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
