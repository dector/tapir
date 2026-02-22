> [!WARNING]
> I use it but I might break this shit in process.
> Be careful.

# pi.dev Container

This project provides a multi-stage container definition at `container/Containerfile` with:

- `bun` installed in a builder stage (default `oven/bun:1.3.9`) and copied into a slim runtime
- `git` installed in runtime (default `debian:bookworm-slim`)
- `tmux` installed in runtime (default `debian:bookworm-slim`)
- `pi` installed globally as a pinned package version (default `@mariozechner/pi-coding-agent@0.54.1`)
- familiar CLI tools preinstalled for agent workflows: `rg` (ripgrep), `fd`, and `jq`
- bun runtime install path set to `/opt/bun/.bun`, install cache path set to `/opt/bun/.bun/install/cache`, and runtime transpiler cache path set to `/opt/bun/.bun/install/cache/@t@` (all writable), while bundled bun globals remain in `/usr/local/bun`
- builder stage runs `pi --help` once to prewarm bun cache, and that cache is copied into `/opt/bun/.bun/install/cache`
- image build metadata is embedded (`commit`, `version`, `build date`) and available via `tapir-version`
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
- `PI_VERSION` (default `0.54.1`)
- `APP_DIR` (default `/project`)
- `TAPIR_VCS_REF` (default `unknown`)
- `TAPIR_BUILD_VERSION` (default `dev`)
- `TAPIR_BUILD_DATE` (default `unknown`)

```bash
podman build -f container/Containerfile \
  --build-arg BUN_IMAGE=docker.io/oven/bun:1.3.9 \
  --build-arg RUNTIME_IMAGE=docker.io/debian:bookworm-slim \
  --build-arg PI_VERSION=0.54.1 \
  --build-arg APP_DIR=/project \
  --build-arg TAPIR_VCS_REF="$(git rev-parse HEAD)" \
  --build-arg TAPIR_BUILD_VERSION="$(git rev-parse --short HEAD)" \
  --build-arg TAPIR_BUILD_DATE="$(date -u +%Y-%m-%dT%H:%M:%SZ)" \
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

### Show embedded image commit/version

```bash
podman run --rm tapir tapir-version
podman run --rm tapir sh -lc 'cat /usr/local/share/tapir/build-info'
```

### Helper script (`tapir.sh`)

Use the included script to mount a workspace directory into `/project`.

By default, `tapir.sh` keeps `pi` auth/settings/sessions in user storage on the host (`~/.local/share/tapir/pi-agent`) and mounts it into the container.
It also keeps Bun cache in host user storage (`~/.local/share/tapir/bun`) and mounts it inside the container as `BUN_INSTALL` (`/opt/bun/.bun`), sets `BUN_INSTALL_CACHE_DIR` to `/opt/bun/.bun/install/cache`, and sets `BUN_RUNTIME_TRANSPILER_CACHE_PATH` to `/opt/bun/.bun/install/cache/@t@` (where Bun stores `.pile` files).

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

- `+install` installs the script to `~/.local/bin/tapir` (or `TAPIR_INSTALL_PATH`) and exits
  - `+install` does not accept workspace or command arguments
- `+tmux` enables tmux wrapping (`session: pi`)
- `+no-user-home` keeps legacy project-local state at `<workspace>/.pi/agent`
- `+version=<tag|sha|this>` chooses image source/version
  - `+version=latest` (default)
  - `+version=<short-sha-or-tag>` for pinned remote image
  - `+version=this` to build and use local `container/Containerfile`

Examples:

```bash
./tapir.sh +install
./tapir.sh +version=latest "$PWD"
./tapir.sh +version=abc1234 "$PWD" tapir-version
./tapir.sh +version=this "$PWD" tapir-version
./tapir.sh +tmux +version=this
./tapir.sh +no-user-home "$PWD"
```

Behavior summary:

- `+version=this`: local dev mode, rebuilds when `container/Containerfile`, `container/entrypoint.sh`, build args, or git commit (`HEAD`) change (hash label)
  - local builds embed commit/version/date metadata for `tapir-version`
  - source root discovery priority: `TAPIR_SOURCE_DIR` → current working directory → workspace argument → script directory
  - set `TAPIR_SOURCE_DIR` explicitly when needed (for example, globally installed `tapir`)
- remote versions: pulls according to pull policy (below)
- default state path: host `~/.local/share/tapir/pi-agent` mounted into container and exported as `PI_CODING_AGENT_DIR`
  - override host path with `TAPIR_AGENT_DIR` (relative paths are resolved under `$HOME`)
  - override container path with `TAPIR_CONTAINER_AGENT_DIR` (must be absolute)
  - use `+no-user-home` to force project-local `<workspace>/.pi/agent`
- default Bun cache path: host `~/.local/share/tapir/bun` mounted into container and exported as `BUN_INSTALL` (`/opt/bun/.bun`)
  - `BUN_INSTALL_CACHE_DIR` is set to `<BUN_INSTALL>/install/cache` (default: `/opt/bun/.bun/install/cache`)
  - `BUN_RUNTIME_TRANSPILER_CACHE_PATH` is set to `<BUN_INSTALL>/install/cache/@t@` (stores Bun runtime `.pile` cache files)
  - override host path with `TAPIR_BUN_DIR` (relative paths are resolved under `$HOME`)
  - override container path with `TAPIR_CONTAINER_BUN_DIR` (must be absolute)
- always runs as host UID/GID (`--userns=keep-id` + `--user`) and mounts workspace as `/project:z`

#### Install as user command

Option 1 (quick install from `trunk`):

```bash
install -d "$HOME/.local/bin"
curl -fsSL "https://raw.githubusercontent.com/dector/tapir/trunk/tapir.sh" -o "$HOME/.local/bin/tapir"
chmod +x "$HOME/.local/bin/tapir"
```

Option 2 (clone + `+install`):

```bash
git clone --branch trunk https://github.com/dector/tapir.git
cd tapir
./tapir.sh +install
```

Custom install target for `+install` (optional):

```bash
TAPIR_INSTALL_PATH="$HOME/.local/bin/tapir" ./tapir.sh +install
```

Ensure `~/.local/bin` is in your `PATH`, then verify:

```bash
tapir +version=latest "$PWD" tapir-version
tapir +version=this "$PWD" tapir-version
TAPIR_SOURCE_DIR="$HOME/src/tapir" tapir +version=this "$PWD" tapir-version
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

#### Image naming, source, and install overrides

- `TAPIR_REMOTE_IMAGE` (defaults to inferred `ghcr.io/<owner>/<repo>` if possible)
- `TAPIR_LOCAL_IMAGE` (default: `tapir:this`)
- `TAPIR_SOURCE_DIR` (explicit source repo root used by `+version=this`)
- `TAPIR_INSTALL_PATH` (install path used by `+install`)
- `TAPIR_AGENT_DIR` (host path for persistent `pi` state; default: `$HOME/.local/share/tapir/pi-agent`; relative paths resolve under `$HOME`)
- `TAPIR_CONTAINER_AGENT_DIR` (container path used for `PI_CODING_AGENT_DIR`; default: `/tapir/.pi/agent`; must be absolute)
- `TAPIR_BUN_DIR` (host path for persistent Bun cache/install data; default: `$HOME/.local/share/tapir/bun`; relative paths resolve under `$HOME`)
- `TAPIR_CONTAINER_BUN_DIR` (container path used for `BUN_INSTALL`; default: `/opt/bun/.bun`; must be absolute; `BUN_INSTALL_CACHE_DIR` becomes `<this>/install/cache`; `BUN_RUNTIME_TRANSPILER_CACHE_PATH` becomes `<this>/install/cache/@t@`)

Build-pin overrides used for local (`+version=this`) builds:

```bash
TAPIR_BUN_IMAGE=docker.io/oven/bun:1.3.9 \
TAPIR_RUNTIME_IMAGE=docker.io/debian:bookworm-slim \
TAPIR_PI_VERSION=0.54.1 \
TAPIR_APP_DIR=/project \
./tapir.sh +version=this "$PWD"
```

## CI publish (GitHub Actions)

A workflow at `.github/workflows/publish-image.yml` builds and publishes the image to GHCR as:

- `ghcr.io/<owner>/tapir:latest`
- `ghcr.io/<owner>/tapir:<short-commit-sha>`

It also sets OCI image labels (`org.opencontainers.image.*`) for traceability and passes build args so `tapir-version` shows commit/version/date inside the container.

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
podman run --rm tapir tapir-version
podman run --rm tapir rg --version
podman run --rm tapir fd --version
podman run --rm tapir jq --version
```
