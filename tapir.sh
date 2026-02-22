#!/usr/bin/env bash

set -euo pipefail

usage() {
  printf 'Usage: %s <workspace-directory> [command [args...]]\n' "$(basename "$0")" >&2
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

container_cmd=(/bin/sh)
if [[ $# -gt 1 ]]; then
  container_cmd=("${@:2}")
fi

exec podman run --rm -it \
  -v "${workspace_dir}:/project" \
  -w /project \
  bun-pi \
  "${container_cmd[@]}"
