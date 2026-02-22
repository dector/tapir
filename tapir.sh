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

run_args=(
  run --rm -it
  --userns=keep-id
  -v "${workspace_dir}:/project:Z"
  -w /project
  bun-pi
)

if [[ $# -gt 1 ]]; then
  exec podman "${run_args[@]}" "${@:2}"
fi

exec podman "${run_args[@]}" /bin/sh
