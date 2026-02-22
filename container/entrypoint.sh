#!/bin/sh

set -eu

if [ "$#" -eq 0 ]; then
  set -- pi --help
fi

if [ "$1" = "pi" ]; then
  if [ "${TAPIR_TMUX:-0}" = "1" ] && [ -t 0 ] && [ -t 1 ]; then
    exec tmux new-session -A -s pi "$@"
  fi

  exec "$@"
fi

exec "$@"
