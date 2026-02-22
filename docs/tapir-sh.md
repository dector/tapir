# `tapir` command reference

This document describes the implemented behavior of the `tapir` launcher (`tapir.sh` in this repository, or installed as `tapir`).

## Usage

```text
tapir [+install] [+tmux] [+no-user-home] [+version=<tag|sha|this>] [workspace-directory] [container-command [args...]]
```

If not installed yet, use `./tapir.sh` with the same arguments.

Flags:

- `+install` install script to `~/.local/bin/tapir` (or `TAPIR_INSTALL_PATH`) and exit
- `+tmux` set `TAPIR_TMUX=1` inside container
- `+no-user-home` store pi state in workspace (`<workspace>/.pi/agent`)
- `+version=<tag|sha|this>` choose image source/version

Defaults:

- Requested version comes from `TAPIR_VERSION` if set, otherwise `latest`
- `+version=...` overrides `TAPIR_VERSION`

## Workspace selection

- If workspace arg is provided, it is used.
- If no workspace arg:
  - allowed only in interactive terminals (`stdin` + `stdout` TTY) and when `CI` is not set
  - prompts: `Using workdir: <pwd> y/N:`
  - continues only if answer is exactly `y`
- In non-interactive/CI mode without workspace arg, script exits with error.

## Image mode selection

- `+version=this` -> **local build** mode
  - image name default: `tapir:this` (override `TAPIR_LOCAL_IMAGE`)
- Any other version -> **remote** mode
  - image ref: `<remote-image>:<version>`

Remote image resolution:

1. `TAPIR_REMOTE_IMAGE` if set
2. `TAPIR_IMAGE` (compat alias) if set
3. inferred from git remote of script directory (`ghcr.io/<owner>/<repo>`)
4. fallback: `ghcr.io/${USER}/tapir`

## Local build mode (`+version=this`)

Container source directory resolution order:

1. `TAPIR_SOURCE_DIR`
2. current shell working directory
3. workspace directory
4. script directory

A directory is valid only if both exist:

- `container/Containerfile`
- `container/entrypoint.sh`

Rebuild decision is hash-based (`tapir.build.hash` label), computed from:

- `container/Containerfile` content
- `container/entrypoint.sh` content
- build pin values (`BUN_IMAGE`, `RUNTIME_IMAGE`, `PI_VERSION`, `APP_DIR`)
- git `HEAD` commit (when available)

If hash differs from existing local image label, script runs `podman build`.

Supported local build override env vars:

- `TAPIR_BUN_IMAGE`
- `TAPIR_RUNTIME_IMAGE`
- `TAPIR_PI_VERSION`
- `TAPIR_APP_DIR`

Local build metadata passed to image:

- `TAPIR_VCS_REF`
- `TAPIR_BUILD_VERSION` (short SHA when available)
- `TAPIR_BUILD_DATE` (UTC ISO-8601)

## Remote pull policy

Env vars:

- `TAPIR_PULL_POLICY=auto|ttl|missing|always|never` (default `auto`)
- `TAPIR_PULL_TTL_SECONDS` (default `600`)
- `TAPIR_PULL_ASYNC=1|0` (default `1`)
- `TAPIR_PULL_STATE_DIR` (default `${XDG_CACHE_HOME:-$HOME/.cache}/tapir/pulls`)

Policy behavior:

- `auto`
  - `latest` -> `ttl`
  - pinned tag/SHA -> `missing`
- `ttl`
  - missing image: blocking pull
  - stale stamp: async pull when `TAPIR_PULL_ASYNC=1`, blocking pull when `0`
- `missing` pull only when image missing locally
- `always` always blocking pull
- `never` fail if image is not local

The script stores pull stamp/lock files in `TAPIR_PULL_STATE_DIR`.

## Runtime invocation behavior

The script runs Podman with:

- `--rm -it`
- `--userns=keep-id`
- `--user <host_uid>:<host_gid>`
- workspace mount: `<workspace>:<container_dir>:z`
- workdir: `<container_dir>` (`TAPIR_APP_DIR`, default `/project`)

If a container command is provided, it runs that command.
Otherwise it runs `pi`.

## Persistent directories

### Bun data

Container Bun base dir:

- `TAPIR_CONTAINER_BUN_DIR` (default `/opt/bun/.bun`, must be absolute)

Host Bun dir:

- `TAPIR_BUN_DIR` (default `$HOME/.local/share/tapir/bun`)
- relative paths are resolved under `$HOME`

When `$HOME` is set, script mounts host Bun dir and exports:

- `BUN_INSTALL=<container_bun_dir>`
- `BUN_INSTALL_CACHE_DIR=<container_bun_dir>/install/cache`
- `BUN_RUNTIME_TRANSPILER_CACHE_PATH=<container_bun_dir>/install/cache/@t@`

### pi agent state

Default mode (without `+no-user-home`):

- host dir: `TAPIR_AGENT_DIR` (default `$HOME/.local/share/tapir/pi-agent`)
- container dir: `TAPIR_CONTAINER_AGENT_DIR` (default `/tapir/.pi/agent`, must be absolute)
- exported env: `PI_CODING_AGENT_DIR=<container_agent_dir>`

`+no-user-home` mode:

- no host state mount
- exported env: `PI_CODING_AGENT_DIR=<container_dir>/.pi/agent`

## Install mode (`+install`)

- Installs current script file to:
  - `TAPIR_INSTALL_PATH`, or
  - `$HOME/.local/bin/tapir`
- Creates parent directory if needed
- Rejects extra args (`workspace`/command are not allowed with `+install`)

## Useful examples

```bash
tapir +version=latest "$PWD"
tapir +version=abc1234 "$PWD" tapir-version
tapir +version=this "$PWD" tapir-version
tapir +tmux +version=this "$PWD"
tapir +no-user-home "$PWD"

TAPIR_PULL_POLICY=always tapir +version=latest "$PWD"
TAPIR_PULL_POLICY=missing tapir +version=abc1234 "$PWD"
TAPIR_PULL_POLICY=never tapir +version=latest "$PWD"
```