#!/usr/bin/env bash

set -euo pipefail

usage() {
  printf 'Usage: %s [+tmux] [+version=<tag|sha|this>] [workspace-directory] [container-command [args...]]\n' "$(basename "$0")" >&2
  printf '  workspace-directory is optional only in interactive non-CI terminals.\n' >&2
}

use_tmux=0
requested_version=${TAPIR_VERSION:-latest}

while [[ "${1:-}" == +* ]]; do
  case "$1" in
    +tmux)
      use_tmux=1
      ;;
    +version=*)
      requested_version=${1#+version=}
      if [[ -z "$requested_version" ]]; then
        printf 'Error: +version requires a value (example: +version=latest).\n' >&2
        usage
        exit 1
      fi
      ;;
    *)
      printf 'Error: unknown option: %s\n' "$1" >&2
      usage
      exit 1
      ;;
  esac

  shift
done

interactive_user_terminal=0
if [[ -t 0 && -t 1 && -z "${CI:-}" ]]; then
  interactive_user_terminal=1
fi

workspace_dir=''
if [[ $# -ge 1 ]]; then
  workspace_dir=$1
  shift
elif [[ $interactive_user_terminal -eq 1 ]]; then
  workspace_dir='.'
  current_pwd=$(pwd)
  printf 'Using workdir: %s y/N: ' "$current_pwd"

  confirmation=''
  if ! IFS= read -r confirmation; then
    exit 1
  fi

  if [[ "$confirmation" != "y" ]]; then
    exit 1
  fi
else
  printf 'Error: missing workspace directory path.\n' >&2
  usage
  exit 1
fi

script_dir=$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)
containerfile="${script_dir}/container/Containerfile"
entrypoint_file="${script_dir}/container/entrypoint.sh"

infer_remote_image() {
  local origin user_name

  origin=''
  if command -v git >/dev/null 2>&1; then
    origin=$(git -C "$script_dir" config --get remote.origin.url 2>/dev/null || true)
    if [[ "$origin" =~ github\.com[:/]([^/]+)/([^/.]+)(\.git)?$ ]]; then
      printf 'ghcr.io/%s/%s\n' "${BASH_REMATCH[1],,}" "${BASH_REMATCH[2]}"
      return 0
    fi
  fi

  user_name=${USER:-tapir}
  printf 'ghcr.io/%s/tapir\n' "${user_name,,}"
}

remote_image=${TAPIR_REMOTE_IMAGE:-${TAPIR_IMAGE:-$(infer_remote_image)}}
local_image=${TAPIR_LOCAL_IMAGE:-tapir:this}

image_mode='remote'
image_name="${remote_image}:${requested_version}"
if [[ "$requested_version" == "this" ]]; then
  image_mode='local'
  image_name=$local_image
fi

bun_image=${TAPIR_BUN_IMAGE:-docker.io/oven/bun:1.3.9}
runtime_image=${TAPIR_RUNTIME_IMAGE:-docker.io/debian:bookworm-slim}
pi_version=${TAPIR_PI_VERSION:-0.54.0}
container_dir=${TAPIR_APP_DIR:-/project}

if [[ ! -e "$workspace_dir" ]]; then
  printf 'Error: path does not exist: %s\n' "$workspace_dir" >&2
  usage
  exit 1
fi

if [[ ! -d "$workspace_dir" ]]; then
  printf 'Error: path is not a directory: %s\n' "$workspace_dir" >&2
  usage
  exit 1
fi

if [[ "$image_mode" == "local" ]]; then
  if [[ ! -f "$containerfile" ]]; then
    printf 'Error: container file not found: %s\n' "$containerfile" >&2
    exit 1
  fi

  if [[ ! -f "$entrypoint_file" ]]; then
    printf 'Error: entrypoint file not found: %s\n' "$entrypoint_file" >&2
    exit 1
  fi

  build_hash=$(
    {
      sha256sum "$containerfile" "$entrypoint_file"
      printf '%s\n' \
        "BUN_IMAGE=$bun_image" \
        "RUNTIME_IMAGE=$runtime_image" \
        "PI_VERSION=$pi_version" \
        "APP_DIR=$container_dir"
    } | sha256sum | cut -d ' ' -f1
  )

  image_hash=''
  if podman image exists "$image_name"; then
    image_hash=$(podman image inspect --format '{{ with .Config.Labels }}{{ index . "tapir.build.hash" }}{{ end }}' "$image_name")
  fi

  if [[ "$image_hash" != "$build_hash" ]]; then
    podman build \
      --label "tapir.build.hash=$build_hash" \
      --build-arg "BUN_IMAGE=$bun_image" \
      --build-arg "RUNTIME_IMAGE=$runtime_image" \
      --build-arg "PI_VERSION=$pi_version" \
      --build-arg "APP_DIR=$container_dir" \
      -f "$containerfile" \
      -t "$image_name" \
      "$script_dir"
  fi
fi

run_args=(
  run --rm -it
  --userns=keep-id
  --user "$(id -u):$(id -g)"
  -v "${workspace_dir}:${container_dir}:z"
  -w "$container_dir"
)

if [[ $use_tmux -eq 1 ]]; then
  run_args+=( -e TAPIR_TMUX=1 )
fi

if [[ $# -gt 0 ]]; then
  exec podman "${run_args[@]}" "$image_name" "$@"
fi

exec podman "${run_args[@]}" "$image_name" pi
