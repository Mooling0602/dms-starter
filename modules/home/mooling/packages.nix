{ pkgs, ... }:

# Home-manager user space module, using by user mooling.

{
  home.packages = with pkgs; [
    btop # System monitor
    lazygit # Git TUI
    gh # GitHub CLI

    # Very useful KDE softwares
    kdePackages.dolphin # KDE filesystem explorer
    kdePackages.dolphin-plugins # Plugins for Dolphin
    kdePackages.baloo
    kdePackages.baloo-widgets
    kdePackages.ffmpegthumbs
    kdePackages.kate # KDE text editor
    kdePackages.discover # KDE software store (Flatpak)
    kdePackages.systemsettings # KDE System Settings
    kdePackages.ark # Zipped file explorer
    # Used by Mooling0602/mooling-skills (request_sudo.md).
    kdePackages.ksshaskpass
    kdePackages.plasma-browser-integration # Seems useless, but just keep it
    kdePackages.gwenview # KDE Image viewer
    kdePackages.filelight # KDE storage size analyzer

    qq # Tencent QQ
    # Wayland-fixed QQ launcher, reachable as "QQ (Wayland fix)" in the app
    # menu; the plain qq entry stays for comparison. The package comes from an
    # overlay in flake.nix.
    linuxqq-wayland-fix
    wechat # WeChat
    telegram-desktop # Chat social media
    discord # Gaming social media
    element-desktop # Chat client in Matrix protocol
    # Best browser from Google.
    # On Linux Chrome picks its keyring backend from XDG_CURRENT_DESKTOP: KDE
    # goes to KWallet's "Chrome Keys/Chrome Safe Storage", everything else
    # (niri falls into DESKTOP_ENVIRONMENT_OTHER) goes to libsecret's "Chrome
    # Safe Storage". The two backends generate independent random keys yet both
    # use the v11 prefix, so after switching desktops the same profile reads
    # the other key, cannot decrypt account tokens and asks for a re-login.
    # Pinning libsecret makes both desktops share one key (gnome-keyring is
    # started on every desktop by modules/system/keyring.nix). See
    # MAINTENANCE.md.
    (google-chrome.override {
      commandLineArgs = "--password-store=gnome-libsecret";
    })
    bilibili # Bilibili video platform
    haruna # video player
    axolotl-launcher-bin # Minecraft Launcher
    pebble-mail # Email client
    openfic # AI Novel workspace
    startlive # Bilibili live streaming without LiveHime
    claude-code # Coding CLI from A\
    codex # OpenAI's coding CLI
    pi # Pi Coding Agent
    dsh # DeepSeek Harness (from git source)
    dsh-desktop # DeepSeek Harness Desktop (build from git source)
    opencode # Coding agent CLI
    opencode-desktop # Coding agent GUI
    zed-editor # Rust based IDE
    reasonix # Coding agent CLI
    reasonix-desktop # Coding agent GUI
    qoder # AI platform
    qoder-ide # AI IDE
    clawd-on-desk # Nice AI pet in desktop
    prismlauncher # Awesome unofficial Minecraft Launcher
    rclone
    zen-browser
    localsend # Local network file share
    deskflow # Share keyboard/mouse across computers (backend: niri-input-portal)
    sleepy-launcher # an-anime-team ZZZ launcher (via aagl-gtk-on-nix overlay)
  ];
}
