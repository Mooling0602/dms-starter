#!/usr/bin/env bash
set -euo pipefail

# Copy the hand written niri overrides of the noctalia session into the
# repository.
#
# custom.kdl is seeded once by Home Manager and then edited by hand, so this
# snapshot and git are the only history it has. Nothing here talks to git:
# review the diff and commit it yourself.

script_dir="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)"
config_home="${XDG_CONFIG_HOME:-$HOME/.config}"

source_file="$config_home/niri-noctalia/custom.kdl"
target_file="$script_dir/custom.kdl"

if [[ ! -f "$source_file" ]]; then
  printf 'Missing niri custom config: %s\n' "$source_file" >&2
  exit 1
fi

install -D -m 0644 -- "$source_file" "$target_file"

printf 'Snapshot updated in %s\n' "$target_file"
