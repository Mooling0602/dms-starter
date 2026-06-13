#!/usr/bin/env bash
set -euo pipefail

script_dir="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)"
config_home="${XDG_CONFIG_HOME:-$HOME/.config}"

dms_source="$config_home/DankMaterialShell"
niri_source="$config_home/niri"
dms_target="$script_dir/dms"
niri_target="$script_dir/niri"

copy_file() {
  local source="$1"
  local target="$2"

  if [[ -f "$source" ]]; then
    install -D -m 0644 "$source" "$target"
  fi
}

if [[ ! -f "$dms_source/settings.json" ]]; then
  printf 'Missing DMS settings: %s\n' "$dms_source/settings.json" >&2
  exit 1
fi

if [[ ! -d "$niri_source" ]]; then
  printf 'Missing Niri config directory: %s\n' "$niri_source" >&2
  exit 1
fi

rm -rf -- "$dms_target" "$niri_target"

mkdir -p -- "$dms_target/plugins"
copy_file "$dms_source/settings.json" "$dms_target/settings.json"

if [[ -d "$dms_source/plugins" ]]; then
  shopt -s nullglob
  for meta_file in "$dms_source"/plugins/*.meta; do
    copy_file "$meta_file" "$dms_target/plugins/$(basename -- "$meta_file")"
  done
  shopt -u nullglob
fi

if [[ -d "$niri_source" ]]; then
  mkdir -p -- "$niri_target"
  cp -a -- "$niri_source/." "$niri_target/"
  find "$niri_target" -type d -name .git -prune -exec rm -rf -- {} +
  chmod -R u+rwX -- "$niri_target"
fi

printf 'Snapshot updated in %s\n' "$script_dir"
