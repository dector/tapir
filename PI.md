# Project Analysis & Suggested Improvements

Overall status: clean, focused setup with a good multi-stage container, slim runtime, tmux-aware entrypoint, and hash-based rebuilds in `tapir.sh`.

## High-impact improvements

1. **Make builds reproducible**
   - Pin base image digests in `container/Containerfile`.
   - Pin `@mariozechner/pi-coding-agent` via `ARG PI_VERSION=...` and install that exact version.
   - Benefit: predictable upgrades and easier rollback.

2. **Add build-context ignore file**
   - Add `.containerignore` (or `.dockerignore`) to exclude `.git/`, `.pi/`, `.bun/`, etc.
   - Benefit: faster builds, smaller context transfer, lower risk of leaking local artifacts into build context.

3. **Reduce runtime image size**
   - Instead of copying all of `/root/.bun`, copy only required runtime artifacts (bun binaries + global package runtime files).
   - Remove unneeded cache files after install.
   - Benefit: smaller image and faster pulls.

4. **Avoid brittle `pi` symlink path**
   - Current symlink points to an internal package path:
     `/usr/local/bun/install/global/node_modules/@mariozechner/pi-coding-agent/dist/cli.js`
   - Prefer using Bun’s global bin shim (`/usr/local/bun/bin/pi`) if available.
   - Benefit: less breakage on package internal layout changes.

## Nice-to-have improvements

5. **Add CI validation**
   - Automate the checks from `AGENTS.md`:
     - `podman build -f container/Containerfile -t tapir .`
     - `podman run --rm tapir bun --version`
     - `podman run --rm tapir git --version`
     - `podman run --rm tapir pi --version`
   - Optional: include `tmux -V` check as in `README.md`.

6. **Improve `tapir.sh` flexibility**
   - Make mount/workdir configurable via env vars.
   - If exposing build args (e.g., `APP_DIR`) in script, include them in build hash logic.
   - Optionally skip forcing `-it` when non-interactive.

7. **Docs consistency**
   - Sync validation commands between `README.md` and `AGENTS.md` (currently `tmux -V` appears in README only).

## Suggested implementation order

1. Reproducibility pinning
2. Build-context ignore file
3. Robust `pi` command wiring
4. CI checks
5. Script/docs polish
