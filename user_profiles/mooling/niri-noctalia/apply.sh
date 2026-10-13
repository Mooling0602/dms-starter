#!/usr/bin/env bash
set -euo pipefail

usage() {
  cat <<'EOF'
Usage: apply.sh [-f|--force]

Restore the hand written niri overrides of the noctalia session from this
snapshot.

Options:
  -f, --force       Skip confirmation when the target file already exists.
  -h, --help        Show this help.
EOF
}

force=false

while (($#)); do
  case "$1" in
    -f|--force)
      force=true
      ;;
    -h|--help)
      usage
      exit 0
      ;;
    *)
      printf 'Unknown argument: %s\n\n' "$1" >&2
      usage >&2
      exit 2
      ;;
  esac
  shift
done

script_dir="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)"
config_home="${XDG_CONFIG_HOME:-$HOME/.config}"
timestamp="$(date +%Y%m%d-%H%M%S)"

snapshot_file="$script_dir/custom.kdl"
config_dir="$config_home/niri-noctalia"
target_file="$config_dir/custom.kdl"
main_config="$config_dir/config.kdl"

if [[ ! -f "$snapshot_file" ]]; then
  printf 'Missing snapshot: %s\n' "$snapshot_file" >&2
  exit 1
fi

if [[ ! -f "$main_config" ]]; then
  printf 'Missing niri config: %s\n' "$main_config" >&2
  exit 1
fi

if ! command -v niri >/dev/null 2>&1; then
  printf 'niri is not available in PATH; cannot validate the snapshot\n' >&2
  exit 1
fi

if ! $force && [[ -e "$target_file" ]]; then
  printf 'Existing niri custom config found:\n  - %s\n' "$target_file" >&2
  answer=""
  read -r -p 'Apply the snapshot and overwrite it? (N/y) ' answer || true
  case "$answer" in
    y|Y)
      ;;
    *)
      printf 'Cancelled. Use -f or --force to skip this confirmation.\n' >&2
      exit 1
      ;;
  esac
fi

# Validate before touching the live file. niri parses this config at every start
# and on every reload, and a parse error is worse than a missing file: the
# running session keeps its old config, but the next login falls back to niri's
# stock defaults and drops everything the repository declares.
#
# The snapshot is checked in a scratch directory mirroring the config directory,
# because a relative include resolves against the directory of the config file
# niri is handed. Files are copied with -L: config.kdl and host.kdl are Home
# Manager symlinks into the store, and copying the links would validate the
# wrong paths.
stage_dir="$(mktemp -d)"
trap 'rm -rf -- "$stage_dir"' EXIT

shopt -s nullglob
for include_file in "$config_dir"/*.kdl; do
  if [[ "$(basename -- "$include_file")" != "custom.kdl" ]]; then
    cp -L -- "$include_file" "$stage_dir/"
  fi
done
shopt -u nullglob

install -D -m 0644 -- "$snapshot_file" "$stage_dir/custom.kdl"

if ! validate_log="$(niri validate -c "$stage_dir/config.kdl" 2>&1)"; then
  printf 'Refusing to apply: the snapshot does not validate\n' >&2
  printf '%s\n' "$validate_log" >&2
  exit 1
fi

if [[ -e "$target_file" ]]; then
  backup_file="$target_file.before-apply-$timestamp"
  cp -L -- "$target_file" "$backup_file"
  printf 'Backed up existing custom config to %s\n' "$backup_file"
fi

install -D -m 0644 -- "$snapshot_file" "$target_file"

printf 'Applied %s from %s\n' "$target_file" "$snapshot_file"
