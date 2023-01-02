#!/usr/bin/env bash

export gs_root_path="$(readlink -f "${BASH_SOURCE[0]}")"
gs_root_path="$(dirname "$gs_root_path")"
gs_root_path="$(dirname "$gs_root_path")"
# shellcheck disable=SC1091  # Not following
source "$gs_root_path/mouse.sh"

mouse_track_start
