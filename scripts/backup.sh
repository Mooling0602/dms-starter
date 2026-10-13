#!/usr/bin/env bash
set -euo pipefail

usage() {
  cat <<'EOF'
Usage: backup.sh <command> [options] [profile ...]

Commands:
  snapshot              Run snapshot.sh for matching profiles.
  apply [-f|--force]    Run apply.sh for matching profiles.
  apply-missing         Restore missing config only, without confirmation.
  niri-custom-snapshot  Snapshot the hand written niri overrides.
  niri-custom-apply     Restore the hand written niri overrides.

If no profile is provided, all profiles with the component scripts are used.
EOF
}

script_dir="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)"
repo_root="$(cd -- "$script_dir/.." && pwd)"
profiles_root="$repo_root/user_profiles"

run_for_profiles() {
  local component="$1"
  local script_name="$2"
  shift 2

  local -a profiles=()
  while (($#)) && [[ "$1" != "--" ]]; do
    profiles+=("$1")
    shift
  done

  if (($#)); then
    shift
  fi

  local -a script_args=("$@")

  if ((${#profiles[@]} == 0)); then
    shopt -s nullglob
    local profile_dir
    for profile_dir in "$profiles_root"/*/"$component"; do
      profiles+=("$(basename -- "$(dirname -- "$profile_dir")")")
    done
    shopt -u nullglob
  fi

  if ((${#profiles[@]} == 0)); then
    printf 'No %s profiles found under %s\n' "$component" "$profiles_root" >&2
    return 1
  fi

  local profile
  for profile in "${profiles[@]}"; do
    local profile_dir="$profiles_root/$profile/$component"
    local script_path="$profile_dir/$script_name"

    if [[ ! -x "$script_path" ]]; then
      printf 'Skipping %s: missing executable %s\n' "$profile" "$script_path" >&2
      continue
    fi

    printf 'Running %s for profile %s\n' "$script_name" "$profile"
    "$script_path" "${script_args[@]}"
  done
}

run_apply() {
  local component="$1"
  shift

  local -a apply_args=()
  local -a profiles=()

  while (($#)); do
    case "$1" in
      -f|--force)
        apply_args+=(--force)
        ;;
      -h|--help)
        usage
        exit 0
        ;;
      --)
        shift
        profiles+=("$@")
        break
        ;;
      -*)
        printf 'Unknown argument: %s\n\n' "$1" >&2
        usage >&2
        exit 2
        ;;
      *)
        profiles+=("$1")
        ;;
    esac
    shift
  done

  run_for_profiles "$component" apply.sh "${profiles[@]}" -- "${apply_args[@]}"
}

if (($# == 0)); then
  usage >&2
  exit 2
fi

command="$1"
shift

case "$command" in
  snapshot)
    run_for_profiles desktop-config snapshot.sh "$@" --
    ;;
  apply)
    run_apply desktop-config "$@"
    ;;
  apply-missing)
    run_for_profiles desktop-config apply.sh "$@" -- --force --missing-only
    ;;
  niri-custom-snapshot)
    run_for_profiles niri-noctalia snapshot.sh "$@" --
    ;;
  niri-custom-apply)
    run_apply niri-noctalia "$@"
    ;;
  -h|--help)
    usage
    ;;
  *)
    printf 'Unknown command: %s\n\n' "$command" >&2
    usage >&2
    exit 2
    ;;
esac
