#!/usr/bin/env bash

set -euo pipefail

usage() {
  printf 'Usage: %s <workspace-directory> [container-command [args...]]\n' "$(basename "$0")" >&2
}

if [[ $# -lt 1 ]]; then
  printf 'Error: missing workspace directory path.\n' >&2
  usage
  exit 1
fi

workspace_dir=$1
script_dir=$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)
image_name=${TAPIR_IMAGE:-bun-pi}
containerfile="${script_dir}/container/Containerfile"

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

if [[ ! -f "$containerfile" ]]; then
  printf 'Error: container file not found: %s\n' "$containerfile" >&2
  exit 1
fi

podman build -f "$containerfile" -t "$image_name" "$script_dir"

run_args=(
  run --rm -it
  --userns=keep-id
  --user "$(id -u):$(id -g)"
  -v "${workspace_dir}:/project:Z"
  -w /project
  "$image_name"
)

if [[ $# -gt 1 ]]; then
  exec podman "${run_args[@]}" "${@:2}"
fi

exec podman "${run_args[@]}" pi
