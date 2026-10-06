# NixOS Configuration: dms-starter

[简体中文](README.md) | English

A modular NixOS Flake configuration template that supports multiple users, multiple devices, and flexible composition of optional desktop modules.

## Supported desktop modules

- [DankMaterialShell](https://danklinux.com/) is complete and actively maintained
- [KDE Plasma](https://wiki.nixos.cn/wiki/KDE) is a work in progress and not yet recommended

## Device identity: username and hostname

`flake.nix` only enumerates the host directories under `hosts/` and **carries no device-specific information**. Each device's identity lives in its own host directory:

```nix
# hosts/<hostname>/default.nix
{ config, hostname, ... }:

let
  # Desktop module in use, matching ./desktop/<desktop>/.
  # Must be a let binding: imports evaluate before config, so referring to
  # config.my.desktop here would recurse infinitely.
  desktop = "dms-with-niri";
in

{
  # Device identity (the only part that differs per host)
  my.username = "user";
  my.hostname = hostname;   # directory name injected by flake.nix
  my.desktop = desktop;

  imports = [
    /* ... */
    ./desktop/${desktop}/default.nix
  ];
  networking.hostName = config.my.hostname;
}
```

When several devices share this repository, each one only edits the few lines at the top of its own `hosts/<hostname>/default.nix`, so they never conflict with or overwrite each other.

The agreed directory names must match the identity:

- `hosts/<hostname>/`: machine-specific configuration
- `modules/home/<username>/`: personal modules, written as needed; missing files are skipped by `utils/optional_import.nix` with an evaluation warning (an older version shipped a `modules/home/user/` template, removed in `a3328c3`)
- `assets/<username>/`: personal assets (avatars and the like)
- `user_profiles/<username>/`: runtime configuration snapshots (see "Runtime configuration backup")

`modules/home/default.nix` only handles **desktop-agnostic** user configuration: it imports `default.nix`, `git.nix`, `packages.nix`, and `avatar.nix` from `modules/home/<username>/` (all optional), plus `hosts/<hostname>/users/<username>.nix` and the shared modules under `modules/home/defaults/`. Shared modules that `modules/home/<username>/` may reference on demand live in `modules/optional/` (for example `screen-recorder.nix` and `kde-connect.nix`).

Desktop-specific Home Manager configuration is **not here**: it is mounted by the current desktop layer through `home-manager.sharedModules` (see the next section), so a desktop that was not selected never pollutes the user environment.

Adding a device only requires creating a new `hosts/<hostname>/default.nix`, with **no change to `flake.nix`** (note that a git flake only packs tracked files, so a new directory must be `git add`ed first).

## Desktop modules

Desktop-related configuration has three layers. When adding or switching a desktop, map them as follows:

```text
hosts/<hostname>/default.nix          # let desktop = "dms-with-niri"; decides which desktop is imported
└── hosts/<hostname>/desktop/<name>/  # host-specific desktop additions
    └── modules/desktop/<name>/       # desktop implementation (system layer + Home Manager layer)
```

- **Switching desktops**: change only the `let desktop = "..."` binding at the top of `hosts/<hostname>/default.nix`; it determines both the value of `my.desktop` and the `imports` path.
- **Consistency check (asserted by the implementation module itself)**: `modules/desktop/<name>/system.nix` asserts that `my.desktop` equals `baseNameOf ./.`, meaning "the desktop declared for use" must equal "the directory name this implementation actually lives in". The desktop name needs no manual maintenance, and the assertion follows automatically if the implementation directory is renamed; a mismatch between declaration and reality (for example declaring `kde-plasma` while importing the `dms-with-niri` implementation) fails at evaluation time.
- **Fallback check**: `modules/system/config.nix` asserts that at least one implementation is loaded. If `hosts/<hostname>/desktop/<name>/default.nix` forgets to import `modules/desktop/<name>/system.nix` (or the path is wrong and silently skipped by `optionalImports`), the implementation module does not exist and its own assertion never runs, so only this fallback can catch it.

### Desktop-specific Home Manager configuration

The desktop implementation layer (`modules/desktop/<name>/system.nix`) mounts its own Home Manager modules into the user environment through `home-manager.sharedModules`. For example, `dms-with-niri` mounts `./default.nix` (the HM layer of `dms-with-niri`) plus the upstream `inputs.dms`, `inputs.danksearch`, and `inputs.dankcalendar` modules.

**This is a deliberate design constraint**: `home-manager.users.<name>.imports` in `flake.nix` only holds desktop-agnostic modules (`./modules/home`, `nvchad`, `codex-desktop`). Any DMS ecosystem module written there would still take effect after switching desktops, which previously caused the problem that `dms.service`, `dsearch.service`, and `fcitx5-dms-theme-sync` remained after switching to KDE. By the same reasoning, desktop-specific `home.activation` steps (such as `restoreDesktopConfig`) must also live inside the desktop layer.

System-layer modules receive `inputs` through `specialArgs`, so they can reference the inputs their own desktop needs directly, with no extra overlay or `extraSpecialArgs` for that desktop in `flake.nix`.

> `imports` evaluates before `config`, so it must **not** be written as `imports = [ ./desktop/${config.my.desktop}/... ]` (that would recurse infinitely); a local variable bound with `let` is required.

## Deploying a new machine

```fish
# 1. After installing NixOS, clone the configuration repository
git clone git@github.com:Mooling0602/dms-starter.git ~/nixos-config

# 2. Run the interactive deploy script
cd ~/nixos-config && ./deploy.sh

# 3. You can also make further changes to improve your fork, and are welcome to keep pulling fixes from this repository
```

`deploy.sh` writes `hosts/<hostname>/default.nix` and fills in `my.username` / `my.hostname`, without touching `flake.nix` at all.

## Daily use on a deployed machine

```fish
cd ~/nixos-config
# modify config -> git commit -> rebuild -> git push
nixos-rebuild-nom switch --flake ~/nixos-config#mooling-laptop
```

`nixos-rebuild-nom` shows build progress through `nix-output-monitor` (`nom`) and preserves the exit status of the original rebuild command.

## System garbage collection

Every NixOS rebuild produces a new generation and boot entry, and these accumulate and consume a lot of space over time.

### Quick cleanup (routine)

```bash
# Remove system generations older than 7 days (also cleans boot entries and old kernels)
sudo nix profile wipe-history --older-than 7d --profile /nix/var/nix/profiles/system

# System-level garbage collection (removes unreferenced /nix/store paths)
sudo nix-collect-garbage --delete-old

# User-level garbage collection (cleans home-manager and user profiles)
nix-collect-garbage --delete-old

# Optimize /nix/store (deduplicate with hard links to save extra space)
sudo nix-store --optimise
```

### Reserved generation limits

The configuration already enables the following automatic policies (see `modules/system/nix.nix` and `hosts/*/default.nix`):

- **`nix.settings.auto-optimise-store = true`**: automatic hard-link optimisation on every build
- **`nix.gc.automatic = true`, `dates = "weekly"` plus `--delete-older-than 1d`**: weekly automatic garbage collection removing generations older than 1 day
- **`boot.loader.systemd-boot.configurationLimit = 10`**: keep at most 10 boot entries

### Manually cleaning old generations (keep only the latest N)

```bash
sudo nix profile wipe-history --profile /nix/var/nix/profiles/system --older-than 7d
```

### Checking the current state

```bash
nix profile history --profile /nix/var/nix/profiles/system    # system generation history
sudo bootctl list                                             # current boot entries
df -h / /boot                                                 # disk usage
du -sh /nix/store                                             # nix store size
```

## Configuration boundaries

- DMS/Niri runtime configuration is not mounted by Home Manager; `~/.config/niri/` and the DMS configuration files are written by the applications themselves.
- Mutable DMS/Niri configuration snapshots are kept in `user_profiles/mooling/desktop-config/`, for backup and review only.
- NvChad Lua configuration comes from the separate repository `github:Mooling0602/NvCfg`; this repository only keeps the `nix4nvchad` wrapper and runtime dependencies.
- The terminal is split into two layers: `modules/home/defaults/terminal.nix` defines the terminal program, fonts, and desktop-agnostic preferences; colors that follow the desktop session live in each desktop module (for example `modules/desktop/dms-with-niri/terminal.nix` references the color files generated by DMS matugen), and Home Manager merges both sides automatically.

## Face authentication

PAM authentication through [Howdy](https://github.com/boltgolt/howdy) is enabled for services that use PAM, such as `sudo`, the local lock screen, and SSH. The DMS Greeter and the `login` authentication stack it reuses exclude Howdy and always require a password, so that GNOME Keyring can be unlocked automatically. For the other services, a successful face match lets the request through, while a failed match still asks for a password.

Howdy shows its detection prompt when authentication starts; if the scene is too dark or recognition times out, enter a password to continue. Enrolling several samples under different lighting and angles improves the recognition rate.

A camera is required. Defaulting this feature to disabled is being considered, and you can change it locally for now.

```fish
# First enrolment; add several samples for different lighting and angles
sudo howdy add mooling

# List or remove enrolled samples
sudo howdy list
sudo howdy remove mooling
```

- During SSH authentication, Howdy scans the local camera and cannot read the camera of the SSH client.
- For ordinary RGB cameras, Howdy provides no reliable liveness detection and can be fooled by a photo, so it should not be treated as a secure replacement for a password.

## Runtime configuration backup

> Mainly for mooling's personal use. You can copy the template or write your own modules as needed.

```fish
# Capture the current mutable DMS/Niri configuration into the repository snapshot
./scripts/backup.sh snapshot mooling

# Restore from the repository snapshot; asks for confirmation (N/y) if related config already exists
./scripts/backup.sh apply mooling

# Skip the confirmation and force a restore
./scripts/backup.sh apply --force mooling
```

- `snapshot.sh` overwrites changed files in the repository snapshot directly, with no confirmation.
- `apply.sh` asks for confirmation by default when DMS/Niri configuration already exists; `-f` or `--force` skips it.
- Both live under each user's `user_profiles/<username>/desktop-config/`, and `scripts/backup.sh` dispatches to them per user.
- `modules/desktop/dms-with-niri/backup.nix` checks the username during Home Manager activation; if the username matches and DMS or Niri configuration is missing, it runs `apply-missing` automatically and skips the confirmation. It is loaded with the DMS desktop layer, so this activation step does not run after switching to another desktop.
- The current DMS snapshot keeps only `settings.json` and plugin `.meta` files, and does not commit `plugin_settings.json`, browser CSS, plugin repository caches, or other files that are volatile or may carry device identifiers.

## References

- [DankMaterialShell documentation](https://danklinux.com/docs/)
- [niri documentation](https://github.com/YaLTeR/niri)
- [NixOS Wiki](https://nixos.wiki/)
