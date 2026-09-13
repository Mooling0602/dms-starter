{ pkgs, ... }:

# Ported from ../mooling/packages.nix, you can choose to keep or delete any package.

{
  home.packages = with pkgs; [
    btop # System monitor
    lazygit # Git TUI
    gh # GitHub CLI

    # Very useful KDE softwares
    kdePackages.dolphin # KDE filesystem explorer
    kdePackages.dolphin-plugins # Plugins for Dolphin
    kdePackages.kate # KDE text editor
    kdePackages.discover # KDE software store (Flatpak)
    kdePackages.systemsettings # KDE System Settings
    kdePackages.ark # Zipped file explorer
    kdePackages.ksshaskpass # Used by https://github.com/Mooling0602/mooling-skills/blob/main/request_sudo.md
    kdePackages.plasma-browser-integration # Seems useless, but just keep it
    kdePackages.gwenview # KDE Image viewer

    qq # 腾讯QQ
    wechat # 微信
    telegram-desktop # Chat social media
    discord # Gaming social media
    element-desktop # Chat client in Matrix protocol
    google-chrome # Best browser from Google
    bilibili # 哔哩哔哩视频平台
    haruna # video player
    axolotl-launcher-bin # Minecraft Launcher
    pebble-mail # Email client
    openfic # AI Novel workspace
    claude-code # Coding CLI from A\
    codex # OpenAI's coding CLI
    pi # Pi Coding Agent
    dsh # DeepSeek Harness (from git source)
    opencode # Coding agent CLI
    opencode-desktop # Coding agent GUI
    zed-editor # Rust based IDE
    reasonix # Coding agent CLI
    reasonix-desktop # Coding agent GUI
    qoder # AI IDE
    clawd-on-desk # Nice AI pet in desktop
    prismlauncher # Awesome unofficial Minecraft Launcher
    rclone
    zen-browser
    localsend # Local network file share
    deskflow # Share keyboard/mouse across computers (backend: niri-input-portal)
    sleepy-launcher # an-anime-team ZZZ launcher (via aagl-gtk-on-nix overlay)
  ];
}
