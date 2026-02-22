# tapir

Minimal Podman image for running [`pi`](https://github.com/mariozechner/pi) with Bun on a slim Debian runtime.

## What you get

- Multi-stage image (`container/Containerfile`)
- Bun + global `pi` install (pinned by default)
- Runtime tools: `git`, `tmux`, `rg`, `fd`, `jq`
- Default container workdir: `/project`
- Helper launcher script: `tapir.sh`

## Quick start

Build locally:

```bash
podman build -f container/Containerfile -t tapir .
```

Run `pi` in your current project:

```bash
podman run --rm -it \
  -v "$PWD":/project \
  -w /project \
  tapir \
  pi
```

## Helper script (`tapir.sh`)

Run with explicit workspace:

```bash
./tapir.sh "$PWD"
```

Interactive shortcut (TTY only, not CI):

```bash
./tapir.sh
```

Install as user command:

```bash
./tapir.sh +install
```

Then use:

```bash
tapir +version=latest "$PWD"
```

## Documentation

Detailed behavior, options, and implementation notes were moved from this README to:

- [`docs/container.md`](docs/container.md) — image contents, build args, entrypoint, metadata
- [`docs/tapir-sh.md`](docs/tapir-sh.md) — script flags, env vars, pull policy, local/remote image resolution
- [`docs/ci-publish.md`](docs/ci-publish.md) — GitHub Actions publish flow

## Pass environment variables

Example:

```bash
podman run --rm -it \
  -v "$PWD":/project \
  -w /project \
  -e OPENAI_API_KEY \
  tapir \
  pi
```

## Quick checks

```bash
podman run --rm tapir bun --version
podman run --rm tapir git --version
podman run --rm tapir pi --version
podman run --rm tapir tapir-version
```
