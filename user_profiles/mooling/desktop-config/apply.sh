#!/usr/bin/env bash
set -euo pipefail

usage() {
  cat <<'EOF'
Usage: apply.sh [-f|--force] [--missing-only]

Apply this desktop-config snapshot to the current user.

Options:
  -f, --force       Skip confirmation when managed config already exists.
  --missing-only    Only restore components whose target config is missing.
  -h, --help        Show this help.
EOF
}

force=false
missing_only=false

while (($#)); do
  case "$1" in
    -f|--force)
      force=true
      ;;
    --missing-only)
      missing_only=true
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

dms_source="$script_dir/dms"
niri_source="$script_dir/niri"
dms_target="$config_home/DankMaterialShell"
niri_target="$config_home/niri"

copy_file() {
  local source="$1"
  local target="$2"

  if [[ -f "$source" ]]; then
    install -D -m 0644 "$source" "$target"
  fi
}

has_dms_config() {
  [[ -f "$dms_target/settings.json" ]]
}

has_niri_config() {
  [[ -f "$niri_target/config.kdl" ]]
}

confirm_overwrite() {
  if $force || { ! has_dms_config && ! has_niri_config; }; then
    return 0
  fi

  printf 'Existing managed desktop config was found:\n' >&2
  if has_dms_config; then
    printf '  - %s\n' "$dms_target/settings.json" >&2
  fi
  if has_niri_config; then
    printf '  - %s\n' "$niri_target" >&2
  fi

  read -r -p 'Apply snapshot and replace existing managed config? (N/y) ' answer
  case "$answer" in
    y|Y)
      return 0
      ;;
    *)
      printf 'Cancelled. Use -f or --force to skip this confirmation.\n' >&2
      exit 1
      ;;
  esac
}

apply_dms() {
  if [[ ! -d "$dms_source" ]]; then
    return 0
  fi

  mkdir -p -- "$dms_target/plugins"
  copy_file "$dms_source/settings.json" "$dms_target/settings.json"

  if [[ -d "$dms_source/plugins" ]]; then
    shopt -s nullglob
    for meta_file in "$dms_source"/plugins/*.meta; do
      copy_file "$meta_file" "$dms_target/plugins/$(basename -- "$meta_file")"
    done
    shopt -u nullglob
  fi
}

apply_niri() {
  if [[ ! -d "$niri_source" ]]; then
    return 0
  fi

  if [[ -e "$niri_target" ]]; then
    backup_path="$niri_target.before-apply-$timestamp"
    mv -- "$niri_target" "$backup_path"
    printf 'Backed up existing niri config to %s\n' "$backup_path"
  fi

  mkdir -p -- "$niri_target"
  cp -a -- "$niri_source/." "$niri_target/"
  chmod -R u+rwX -- "$niri_target"
}

if $missing_only; then
  applied=false

  if has_dms_config; then
    printf 'DMS config already exists; skipping.\n'
  else
    apply_dms
    applied=true
  fi

  if has_niri_config; then
    printf 'Niri config already exists; skipping.\n'
  else
    apply_niri
    applied=true
  fi

  if ! $applied; then
    printf 'No missing desktop config to apply.\n'
  fi

  exit 0
fi

confirm_overwrite
apply_dms
apply_niri

printf 'Desktop config applied from %s\n' "$script_dir"
