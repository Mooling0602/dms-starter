# NixOS + DMS + Niri 配置

## 项目结构

> 该部分信息存在滞后性，当前版本：2026-05-31 14:15

```
~/nixos-config/
├── assets/                        # 静态资源
│   ├── avatar.jpg                # 用户头像
│   ├── wallpaper-dark-cyrene.png  # 深色模式壁纸
│   └── wallpaper-light-kokomi.png # 浅色模式壁纸
├── flake.nix                      # 入口，home-manager + DMS + greetd 集成
├── flake.lock
├── hosts/mooling-laptop/          # 机器专属（硬件驱动 + boot + hostname）
│   ├── default.nix               # imports 系统/home 模块 + boot + hostname + stateVersion
│   ├── gpu.nix                   # NVIDIA 驱动 + Intel/NVIDIA Prime offload
│   └── hardware-configuration.nix # 自动生成（磁盘 UUID、内核模块）
├── modules/
│   ├── home/                     # Home Manager 模块（跨机器复用）
│   │   ├── default.nix           # 入口：username、homeDirectory、imports
│   │   ├── packages.nix          # 用户包（CLI 工具、GUI 应用）
│   │   ├── theme.nix             # Qt、fontconfig、xdg.portal、xresources、主题相关包
│   │   ├── desktop.nix           # DMS、niri symlinks、alacritty、壁纸/头像、dms-set-avatar
│   │   └── git.nix               # git 用户配置
│   └── system/                   # 通用系统模块（可跨机器复用）
│       ├── desktop.nix           # dms-greeter + niri + Firefox
│       ├── fonts.nix             # 系统级字体
│       ├── i18n.nix              # zh_CN 语言 + fcitx5 中文输入法（waylandFrontend）
│       ├── networking.nix        # NetworkManager + 防火墙关闭 + Clash Verge
│       ├── nix.nix               # nix.settings + 自动 GC
│       ├── packages.nix          # 系统包 + unfree + nautilus 排除 + Dolphin 右键菜单修复
│       ├── services.nix          # 蓝牙 + 打印 + PipeWire + SSH
│       └── users.nix             # 用户 mooling + fish + sudo NOPASSWD
├── niri/                          # Niri KDL 配置（mkOutOfStoreSymlink 管理，DMS 可写）
│   ├── config.kdl                # 手动维护：input、环境变量、layer-rules、DMS includes
│   └── dms/                      # DMS 生成的文件（dms setup 产出）
│       ├── alttab.kdl
│       ├── binds.kdl
│       ├── colors.kdl
│       ├── cursor.kdl
│       ├── layout.kdl
│       ├── outputs.kdl
│       ├── windowrules.kdl
│       └── wpblur.kdl
└── README.md
```

## 重建命令

```fish
sudo nixos-rebuild switch --flake ~/nixos-config#mooling-laptop
```

## 工作流程

每次修改配置时按此顺序操作：

1. **修改** — 编辑配置文件

2. **提交** — `git commit` 到本地

3. **重建验证** — `sudo nixos-rebuild switch --flake ~/nixos-config#mooling-laptop`，确认无报错

4. **推送** — `git push`

5. **提交信息格式** — 使用 `Co-Authored-By: Claude Code CLI <noreply@anthropic.com>`

> 非Claude Code客户端请忽略，或使用适合自己的正确信息。

## 关键设计决策

1. **Niri 配置用 mkOutOfStoreSymlink** — 源自 [DMS issue #1788](https://github.com/AvengeMedia/DankMaterialShell/issues/1788)。移除了 `niri-flake` 和 DMS 的 `niri.includes` 模块，改用 `xdg.configFile` + `config.lib.file.mkOutOfStoreSymlink` 指向 `~/nixos-config/niri/`。DMS 可自由写入，改动直接进 git。

2. **DMS 用 systemd 管理** — `systemd.enable = true`，不用 `niri.enableSpawn`。DMS 崩溃会自动重启。

3. **Qt 环境变量写 environment.d** — `systemd.user.sessionVariables` 同时设置了 `QT_QPA_PLATFORMTHEME=qt6ct` 和 `QT_QPA_PLATFORMTHEME_QT6=qt6ct`，确保 niri 和 DMS 启动的应用都能拿到正确的 Qt 变量。niri 里也设了一份同样的值（`programs.niri.settings.environment`）。两者保持一致。

4. **字体分两级** — 系统级 `fonts.packages`（greeter 可见）+ 用户级 `home.packages`（fontconfig 使用）。

5. **DMS session 持久化** — `programs.dank-material-shell.session` 声明了壁纸路径、`perModeWallpaper`。壁纸文件通过 `home.file` 拷贝到 `~/.local/share/wallpapers/`。

## Niri 配置文件管理

- `config.kdl` 手动维护，包含 input、环境变量、layer-rules、DMS includes
- `dms/*.kdl` 由 `dms setup` 生成
- 需要重新生成时：`echo -e "1\n1-3\n1\ny" | DMS_PRIVESC=sudo dms setup`
- 生成后用 `git diff` 审查，确认后提交

## 已修复的关键问题

| 问题 | 方案 |
|------|------|
| config.kdl 反复冲突 | mkOutOfStoreSymlink |
| Qt 应用 DMS 启动时 env 错误 | systemd.user.sessionVariables 写入 environment.d |
| Qt 标题栏风格 | 去掉 QT_WAYLAND_DISABLE_WINDOWDECORATION，让 Qt 用 Breeze CSD |
| Dolphin 右键"打开方式"无应用 | `applications.menu` symlink |
| Greeter 不跟随桌面主题 | `configHome = "/home/mooling"` |
| 蓝牙不可用 | `hardware.bluetooth.enable` |
| 头像重启丢失 | systemd oneshot 服务 + 重试脚本 |
| 文件选择器走 GNOME | xdg-desktop-portal-kde + portals.conf |
| Alacritty 不跟随浅色/暗色模式 | 导入 DMS 生成的 `dank-theme.toml` |
| DMS 不随系统启动 | 从 niri spawn 切换到 systemd 管理 |
| NVIDIA 驱动 | hardware.nvidia 配置 + Prime offload |
| fcitx5 Wayland 警告 | `waylandFrontend = true` |

## 未解决的问题

- niri 概览中工作区卡片的透明阴影边框 — 来源未定位（不是 shadow、不是 recent-windows、不是 m3Elevation）

## 待优化

- `niri/hm.kdl` 是旧残留，可以删除
- `assets/README.md` 是自动生成的，可以删除
- 详情参见 `https://github.com/AvengeMedia/DankMaterialShell/issues/1788`
