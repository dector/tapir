# AGENTS.md

Minimal Bun + `pi` container (`debian:bookworm-slim` runtime, multi-stage build).

## Rules

- Keep `Containerfile` multi-stage.
- Keep default command as `pi --help`.
- If runtime/build behavior changes, update `README.md`.

## Defaults

- Workdir: `/project`.
- Build arg override: `APP_DIR`.

## Validate

```bash
podman build -f Containerfile -t bun-pi .
podman run --rm bun-pi bun --version
podman run --rm bun-pi git --version
podman run --rm bun-pi pi --version
```
