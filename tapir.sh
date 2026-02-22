#!/usr/bin/env bash

set -euo pipefail

script_path="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)/$(basename "${BASH_SOURCE[0]}")"
script_dir="$(dirname "$script_path")"

usage() {
  printf 'Usage: %s [+install] [+tmux] [+no-user-home] [+version=<tag|sha|this>] [workspace-directory] [container-command [args...]]\n' "$(basename "$0")" >&2
  printf '  +install installs this script to ~/.local/bin/tapir (or TAPIR_INSTALL_PATH).\n' >&2
  printf '  +no-user-home stores pi state in the workspace (.pi/agent) instead of user storage.\n' >&2
  printf '  workspace-directory is optional only in interactive non-CI terminals.\n' >&2
}

install_self() {
  local default_install_path install_target install_dir

  default_install_path=''
  if [[ -n "${HOME:-}" ]]; then
    default_install_path="${HOME}/.local/bin/tapir"
  fi

  install_target=${TAPIR_INSTALL_PATH:-$default_install_path}
  if [[ -z "$install_target" ]]; then
    printf 'Error: cannot determine install target. Set HOME or TAPIR_INSTALL_PATH.\n' >&2
    exit 1
  fi

  install_dir=$(dirname "$install_target")
  mkdir -p "$install_dir"

  install -Dm755 "$script_path" "$install_target"

  printf 'Installed tapir to: %s\n' "$install_target"
  printf 'Ensure this directory is in PATH: %s\n' "$install_dir"
}

use_tmux=0
install_requested=0
use_user_home=1
requested_version=${TAPIR_VERSION:-latest}

while [[ "${1:-}" == +* ]]; do
  case "$1" in
    +install)
      install_requested=1
      ;;
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
    +no-user-home)
      use_user_home=0
      ;;
    *)
      printf 'Error: unknown option: %s\n' "$1" >&2
      usage
      exit 1
      ;;
  esac

  shift
done

if [[ $install_requested -eq 1 ]]; then
  if [[ $# -gt 0 ]]; then
    printf 'Error: +install does not accept workspace or command arguments.\n' >&2
    usage
    exit 1
  fi

  install_self
  exit 0
fi

interactive_user_terminal=0
if [[ -t 0 && -t 1 && -z "${CI:-}" ]]; then
  interactive_user_terminal=1
fi

current_pwd=$(pwd)

workspace_dir=''
if [[ $# -ge 1 ]]; then
  workspace_dir=$1
  shift
elif [[ $interactive_user_terminal -eq 1 ]]; then
  workspace_dir='.'
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

has_container_sources() {
  local source_dir=$1
  [[ -f "${source_dir}/container/Containerfile" && -f "${source_dir}/container/entrypoint.sh" ]]
}

resolve_source_dir() {
  local workspace_dir_abs=$1
  local resolved_source_dir=''

  if [[ -n "${TAPIR_SOURCE_DIR:-}" ]]; then
    if [[ ! -d "$TAPIR_SOURCE_DIR" ]]; then
      printf 'Error: TAPIR_SOURCE_DIR is not a directory: %s\n' "$TAPIR_SOURCE_DIR" >&2
      exit 1
    fi

    resolved_source_dir=$(cd "$TAPIR_SOURCE_DIR" && pwd)
    if ! has_container_sources "$resolved_source_dir"; then
      printf 'Error: TAPIR_SOURCE_DIR does not contain container sources: %s\n' "$resolved_source_dir" >&2
      exit 1
    fi

    printf '%s\n' "$resolved_source_dir"
    return 0
  fi

  for candidate in "$current_pwd" "$workspace_dir_abs" "$script_dir"; do
    if has_container_sources "$candidate"; then
      printf '%s\n' "$candidate"
      return 0
    fi
  done

  printf 'Error: could not locate container sources (expected container/Containerfile and container/entrypoint.sh).\n' >&2
  printf 'Set TAPIR_SOURCE_DIR to the tapir repository root.\n' >&2
  exit 1
}

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

cache_base=${XDG_CACHE_HOME:-${HOME:-/tmp}/.cache}
pull_state_dir=${TAPIR_PULL_STATE_DIR:-${cache_base}/tapir/pulls}

is_fresh_pull_stamp() {
  local stamp_file=$1
  local ttl_seconds=$2
  local now_epoch last_epoch

  if [[ ! -f "$stamp_file" ]]; then
    return 1
  fi

  if ! IFS= read -r last_epoch < "$stamp_file"; then
    return 1
  fi

  if [[ ! "$last_epoch" =~ ^[0-9]+$ ]]; then
    return 1
  fi

  now_epoch=$(date +%s)
  (( now_epoch - last_epoch < ttl_seconds ))
}

pull_with_stamp() {
  local image_ref=$1
  local stamp_file=$2
  local lock_file=$3
  local blocking=$4

  mkdir -p "$pull_state_dir"

  if command -v flock >/dev/null 2>&1; then
    if [[ "$blocking" == "1" ]]; then
      (
        flock 9
        podman pull "$image_ref"
        date +%s > "$stamp_file"
      ) 9>"$lock_file"
      return
    fi

    (
      flock -n 9 || exit 0
      podman pull "$image_ref" >/dev/null 2>&1 && date +%s > "$stamp_file"
    ) 9>"$lock_file" >/dev/null 2>&1 &
    return
  fi

  if [[ "$blocking" == "1" ]]; then
    podman pull "$image_ref"
    date +%s > "$stamp_file"
    return
  fi

  (podman pull "$image_ref" >/dev/null 2>&1 && date +%s > "$stamp_file") >/dev/null 2>&1 &
}

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

workspace_dir_abs=$(cd "$workspace_dir" && pwd)

if [[ "$image_mode" == "local" ]]; then
  source_dir=$(resolve_source_dir "$workspace_dir_abs")
  containerfile="${source_dir}/container/Containerfile"
  entrypoint_file="${source_dir}/container/entrypoint.sh"
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
      "$source_dir"
  fi
fi

if [[ "$image_mode" == "remote" ]]; then
  configured_pull_policy=${TAPIR_PULL_POLICY:-auto}
  pull_ttl_seconds=${TAPIR_PULL_TTL_SECONDS:-600}
  pull_async=${TAPIR_PULL_ASYNC:-1}

  case "$configured_pull_policy" in
    auto)
      if [[ "$requested_version" == "latest" ]]; then
        pull_policy='ttl'
      else
        pull_policy='missing'
      fi
      ;;
    ttl|missing|always|never)
      pull_policy=$configured_pull_policy
      ;;
    *)
      printf 'Error: invalid TAPIR_PULL_POLICY: %s (expected auto|ttl|missing|always|never).\n' "$configured_pull_policy" >&2
      exit 1
      ;;
  esac

  if [[ ! "$pull_ttl_seconds" =~ ^[0-9]+$ ]]; then
    printf 'Error: TAPIR_PULL_TTL_SECONDS must be a non-negative integer, got: %s\n' "$pull_ttl_seconds" >&2
    exit 1
  fi

  local_exists=0
  if podman image exists "$image_name"; then
    local_exists=1
  fi

  image_key=$(printf '%s' "$image_name" | sha256sum | cut -d ' ' -f1)
  pull_stamp_file="${pull_state_dir}/${image_key}.stamp"
  pull_lock_file="${pull_state_dir}/${image_key}.lock"

  case "$pull_policy" in
    never)
      if [[ $local_exists -eq 0 ]]; then
        printf 'Error: image not present locally and pulling is disabled: %s\n' "$image_name" >&2
        exit 1
      fi
      ;;
    missing)
      if [[ $local_exists -eq 0 ]]; then
        pull_with_stamp "$image_name" "$pull_stamp_file" "$pull_lock_file" 1
      fi
      ;;
    always)
      pull_with_stamp "$image_name" "$pull_stamp_file" "$pull_lock_file" 1
      ;;
    ttl)
      if [[ $local_exists -eq 0 ]]; then
        pull_with_stamp "$image_name" "$pull_stamp_file" "$pull_lock_file" 1
      elif ! is_fresh_pull_stamp "$pull_stamp_file" "$pull_ttl_seconds"; then
        if [[ "$pull_async" == "1" ]]; then
          pull_with_stamp "$image_name" "$pull_stamp_file" "$pull_lock_file" 0
        else
          pull_with_stamp "$image_name" "$pull_stamp_file" "$pull_lock_file" 1
        fi
      fi
      ;;
  esac
fi

run_args=(
  run --rm -it
  --userns=keep-id
  --user "$(id -u):$(id -g)"
  -v "${workspace_dir}:${container_dir}:z"
  -w "$container_dir"
)

if [[ $use_user_home -eq 1 ]]; then
  if [[ -z "${HOME:-}" ]]; then
    printf 'Error: HOME is not set, cannot use user storage for pi state.\n' >&2
    printf 'Run with +no-user-home or set HOME.\n' >&2
    exit 1
  fi

  host_agent_dir=${TAPIR_AGENT_DIR:-${HOME}/.local/share/tapir/pi-agent}
  container_agent_dir=${TAPIR_CONTAINER_AGENT_DIR:-/tapir/.pi/agent}

  if [[ -e "$host_agent_dir" && ! -d "$host_agent_dir" ]]; then
    printf 'Error: TAPIR_AGENT_DIR is not a directory: %s\n' "$host_agent_dir" >&2
    exit 1
  fi

  mkdir -p "$host_agent_dir"
  run_args+=(
    -v "${host_agent_dir}:${container_agent_dir}:z"
    -e "PI_CODING_AGENT_DIR=${container_agent_dir}"
  )
else
  run_args+=( -e "PI_CODING_AGENT_DIR=${container_dir}/.pi/agent" )
fi

if [[ $use_tmux -eq 1 ]]; then
  run_args+=( -e TAPIR_TMUX=1 )
fi

if [[ $# -gt 0 ]]; then
  exec podman "${run_args[@]}" "$image_name" "$@"
fi

exec podman "${run_args[@]}" "$image_name" pi
