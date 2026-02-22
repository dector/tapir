# Container image details

This document describes the implemented behavior of `container/Containerfile` and `container/entrypoint.sh`.

## Build layout

`container/Containerfile` is multi-stage:

1. **builder** (`BUN_IMAGE`, default `docker.io/oven/bun:1.3.9`)
   - Installs `@mariozechner/pi-coding-agent@${PI_VERSION}` globally with Bun.
   - Runs `pi --help` once to prewarm Bun cache.
2. **runtime** (`RUNTIME_IMAGE`, default `docker.io/debian:bookworm-slim`)
   - Installs runtime packages:
     - `ca-certificates`
     - `git`
     - `tmux`
     - `ripgrep`
     - `fd-find`
     - `jq`
   - Copies Bun binary, Bun global install, and warmed cache from builder.

## Build args

- `BUN_IMAGE` (default: `docker.io/oven/bun:1.3.9`)
- `RUNTIME_IMAGE` (default: `docker.io/debian:bookworm-slim`)
- `PI_VERSION` (default: `0.54.1`)
- `APP_DIR` (default: `/project`)
- `TAPIR_VCS_REF` (default: `unknown`)
- `TAPIR_BUILD_VERSION` (default: `dev`)
- `TAPIR_BUILD_DATE` (default: `unknown`)

## Runtime paths and env

Implemented runtime env vars:

- `BUN_INSTALL=/opt/bun/.bun`
- `BUN_INSTALL_CACHE_DIR=/opt/bun/.bun/install/cache`
- `BUN_RUNTIME_TRANSPILER_CACHE_PATH=/opt/bun/.bun/install/cache/@t@`
- `TAPIR_BUN_BUNDLED_DIR=/usr/local/bun`
- `TAPIR_BUILD_COMMIT`, `TAPIR_BUILD_VERSION`, `TAPIR_BUILD_DATE`

Other setup:

- Symlink `node -> bun`
- Symlink `fd -> fdfind`
- Symlink `pi` to installed CLI JS entrypoint
- Bun writable cache dir under `/opt/bun`

## Embedded build metadata

Image embeds metadata in two forms:

- OCI labels:
  - `org.opencontainers.image.revision`
  - `org.opencontainers.image.version`
  - `org.opencontainers.image.created`
- Runtime files/commands:
  - `/usr/local/share/tapir/build-info`
  - `/usr/local/bin/tapir-version`

Check:

```bash
podman run --rm tapir tapir-version
podman run --rm tapir sh -lc 'cat /usr/local/share/tapir/build-info'
```

## Entrypoint behavior

`container/entrypoint.sh` behavior:

- No args passed -> defaults to `pi --help`
- If first arg is `pi` and `TAPIR_TMUX=1` with interactive TTY -> runs `tmux new-session -A -s pi "$@"`
- Otherwise executes command directly

Container defaults:

- `ENTRYPOINT ["/usr/local/bin/container-entrypoint.sh"]`
- `CMD ["pi", "--help"]`
- `WORKDIR ${APP_DIR}` (default `/project`)

## Minimal build context

`.dockerignore` includes only container build files:

- `container/Containerfile`
- `container/entrypoint.sh`
- `.dockerignore`

This keeps `podman build` context small.

## Validation

```bash
podman build -f container/Containerfile -t tapir .
podman run --rm tapir bun --version
podman run --rm tapir git --version
podman run --rm tapir tmux -V
podman run --rm tapir pi --version
podman run --rm tapir rg --version
podman run --rm tapir fd --version
podman run --rm tapir jq --version
```