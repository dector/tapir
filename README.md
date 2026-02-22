# tapir

`tapir` is the intended way to run [`pi`](https://github.com/mariozechner/pi) in a reproducible Podman environment.

The container image is an implementation detail behind the `tapir` command.

## Install `tapir`

### Option 1: quick install (curl)

```bash
install -d "$HOME/.local/bin"
curl -fsSL "https://raw.githubusercontent.com/dector/tapir/trunk/tapir.sh" -o "$HOME/.local/bin/tapir"
chmod +x "$HOME/.local/bin/tapir"
```

### Option 2: clone + install

```bash
git clone --branch trunk https://github.com/dector/tapir.git
cd tapir
./tapir.sh +install
```

Make sure `~/.local/bin` is in your `PATH`.

## Quick start

Run `pi` for your current project:

```bash
tapir
```

## Possible usages

### 1) Default mode

```bash
tapir "$PWD"
```

### 2) Passing different `+` options

```bash
tapir +tmux "$PWD"
tapir +version=latest "$PWD"
tapir +version=<tag-or-sha> "$PWD"
```

### 3) Passing a different command

Anything after the workspace path is executed inside the container:

```bash
tapir "$PWD" pi --help
tapir "$PWD" tapir-version
tapir "$PWD" sh -lc 'ls -la'
```

### 4) Running custom binaries from your project

Use an explicit project directory and run binaries relative to it:

```bash
tapir /path/to/project ./scripts/my-tool
tapir "$PWD" ./node_modules/.bin/eslint .
```

### 5) Getting versions of everything

```bash
tapir "$PWD" tapir-version
tapir "$PWD" bun --version
tapir "$PWD" pi --version
tapir "$PWD" git --version
tapir "$PWD" tmux -V
tapir "$PWD" rg --version
tapir "$PWD" fd --version
tapir "$PWD" jq --version
```

## Common options

- `+tmux` — run `pi` in a `tmux` session (`pi`)
- `+no-user-home` — keep state in `<workspace>/.pi/agent`
- `+version=<tag|sha|this>` — choose remote image version or local build

## Requirements

- Podman
- Linux/macOS shell environment with standard coreutils

## Documentation

- [`docs/tapir-sh.md`](docs/tapir-sh.md) — command behavior, flags, env vars
- [`docs/how-it-works.md`](docs/how-it-works.md) — implementation details (image/build/runtime internals)
- [`docs/ci-publish.md`](docs/ci-publish.md) — CI image publishing
