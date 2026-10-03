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
    kdePackages.ksshaskpass # Used by https://github.com/Mooling0602/mooling-skills/blob/main/request_sudo.md
    kdePackages.plasma-browser-integration # Seems useless, but just keep it
    kdePackages.gwenview # KDE Image viewer
    kdePackages.filelight # KDE storage size analyzer

    qq # 腾讯QQ
    wechat # 微信
    telegram-desktop # Chat social media
    discord # Gaming social media
    element-desktop # Chat client in Matrix protocol
    # Best browser from Google.
    # Chrome 在 Linux 上按 XDG_CURRENT_DESKTOP 自动挑选密钥后端：KDE 走
    # KWallet 的「Chrome Keys/Chrome Safe Storage」，其他（niri 落进
    # DESKTOP_ENVIRONMENT_OTHER）走 libsecret 的「Chrome Safe Storage」。
    # 两个后端各自独立随机生成密钥，且都用同一个 v11 前缀，因此换桌面后
    # 同一份 profile 会去读另一把钥匙，账户令牌解不开、要求重新登录。
    # 钉死 libsecret 后两个桌面共用同一把钥匙（gnome-keyring 由
    # modules/system/keyring.nix 在所有桌面下启动）。见 MAINTENANCE.md。
    (google-chrome.override {
      commandLineArgs = "--password-store=gnome-libsecret";
    })
    bilibili # 哔哩哔哩视频平台
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
