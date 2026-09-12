# NixOS + DMS + Niri 配置

## 项目结构

> 该部分信息存在滞后性，当前版本：2026-09-12 16:00

```
~/nixos-config/
├── assets/                        # 静态资源
│   ├── mooling/                   # 个人资源（目录名与 flake.nix 的 username 同名）
│   │   └── avatar.jpg             # 用户头像
│   ├── wallpaper-dark-cyrene.png  # 深色模式壁纸
│   └── wallpaper-light-kokomi.png # 浅色模式壁纸
├── deploy.sh                      # 新机器交互式部署脚本
├── flake.nix                      # 入口，home-manager + DMS + greetd 集成
├── flake.lock
├── hosts/mooling-laptop/          # 机器专属（硬件驱动 + boot + hostname）
│   ├── default.nix                # imports 系统/home 模块 + boot + hostname + stateVersion
│   ├── gpu.nix                    # NVIDIA 驱动 + Intel/NVIDIA Prime offload
│   ├── nix-builder.nix            # aarch64-linux 远程构建节点
│   ├── clash-verge-fix.nix        # Mihomo TUN 的 UPnP/SSDP 路由绕过
│   └── hardware-configuration.nix # 自动生成（磁盘 UUID、内核模块）
├── MAINTENANCE.md                 # 维护清单（上游覆盖、移除条件与复查方法）
├── modules/
│   ├── home/                      # Home Manager 模块（跨机器复用）
│   │   ├── default.nix            # 入口：username、homeDirectory、imports
│   │   ├── backup.nix             # 运行时配置缺失时自动恢复快照
│   │   ├── defaults/              # 所有用户共用的模块
│   │   │   ├── desktop.nix        # DMS、终端、壁纸
│   │   │   ├── nvchad.nix         # nix4nvchad 包装和依赖
│   │   │   ├── obs.nix            # OBS Studio 与插件
│   │   │   ├── packages.nix       # 通用用户包（CLI 工具、开发工具）
│   │   │   ├── ssh.nix            # SSH 客户端配置
│   │   │   ├── theme.nix          # Qt、fontconfig、xdg.portal、xresources、主题相关包
│   │   │   └── wine.nix           # 禁用 winealsa.drv（WINEDLLOVERRIDES）
│   │   ├── mooling/               # mooling 的个人模块（目录名与 flake.nix 的 username 同名）
│   │   │   ├── avatar.nix         # ~/.face 与 ~/.face.icon 头像
│   │   │   ├── git.nix            # git 用户配置与 SSH 签名
│   │   │   ├── packages.nix       # 个人包（KDE 应用、聊天、游戏、AI CLI）
│   │   │   └── utils.nix          # 个人脚本（region-record 选区录屏）
│   │   └── user/                  # 新用户模板（复制为 modules/home/<username>/）
│   │       ├── avatar.nix
│   │       ├── git.nix
│   │       ├── packages.nix
│   │       └── utils.nix
│   └── system/                    # 通用系统模块（可跨机器复用）
│       ├── config.nix             # my.username / my.hostname 选项定义
│       ├── desktop.nix            # dms-greeter + niri + Firefox
│       ├── fonts.nix              # 系统级字体
│       ├── i18n.nix               # zh_CN 语言 + fcitx5 中文输入法（waylandFrontend）
│       ├── networking.nix         # NetworkManager + 防火墙关闭 + Clash Verge
│       ├── nix.nix                # nix.settings + 自动 GC
│       ├── obs.nix                # OBS 虚拟摄像头（v4l2loopback）+ polkit 规则
│       ├── packages.nix           # 系统包 + unfree + nautilus 排除 + Dolphin 右键菜单修复
│       ├── services.nix           # 蓝牙 + 打印 + PipeWire + SSH + Howdy
│       ├── users.nix              # 用户 mooling + fish + sudo NOPASSWD
│       └── virtualisation.nix     # 虚拟化配置
├── patches/                       # 上游补丁（dlib-build-cores.patch）
├── README.md                      # 模块结构、部署与日常使用说明
├── scripts/                       # 辅助脚本
└── user_profiles/                 # 用户运行时配置快照
    └── mooling/
        └── desktop-config/        # DMS/Niri 可变配置备份
```

## 工作流程

每次修改配置时按此顺序操作：

1. **修改** - 编辑配置文件

2. **提交** - `git commit` 到本地

> 在重建前进行提交，可以避免 `warning: Git tree '/home/mooling/nixos-config' is dirty` 警告和 git 未暂存引发的重建报错。快速验证时 git add . 即可。

3. **重建切换并验证** - `sudo nixos-rebuild switch --flake ~/nixos-config#mooling-laptop`，确认无报错

4. **推送** - `git push`

5. **提交信息格式** - 不添加任何 `Co-Authored-By` 之类的尾注，直接以用户身份使用语义化格式提交。

尊重用户自行修改和管理的意愿，只有在用户明确表示无需再行询问时，才直接按上述内容执行操作。

## 维护清单

- `MAINTENANCE.md` 记录临时构建绕过、外部功能补丁、任何替代上游包源的 fork（不限定所有者）及配置例外的原因、上游链接、移除条件和复查命令。
- 更新 `flake.lock`、相关依赖或覆盖时，可以先检查该清单；上游已修复时删除（或者归档）对应覆盖，并按文档完成验证。

## 关键设计决策

1. **DMS/Niri 运行配置不进行声明式管理** - 不声明 `programs.dank-material-shell.session`，也不通过 `xdg.configFile` 或 `mkOutOfStoreSymlink` 挂载 `~/.config/niri/config.kdl` 和 `~/.config/niri/dms/*.kdl`。DMS 拥有自身运行配置和 `~/.config/niri/`，避免图形设置只读或重启后被 Nix 覆盖。

2. **DMS 用 systemd 管理** - `systemd.enable = true`，不用 `niri.enableSpawn`。DMS 崩溃会自动重启。

3. **Qt 环境变量写 environment.d** - `systemd.user.sessionVariables` 同时设置了 `QT_QPA_PLATFORMTHEME=qt6ct` 和 `QT_QPA_PLATFORMTHEME_QT6=qt6ct`，确保 niri 和 DMS 启动的应用都能拿到正确的 Qt 变量。niri 里也设了一份同样的值（`programs.niri.settings.environment`）。两者保持一致。

4. **字体分两级** - 系统级 `fonts.packages`（greeter 可见）+ 用户级 `home.packages`（fontconfig 使用）。

5. **壁纸/头像资源仍由 Nix 提供** - 壁纸文件通过 `home.file` 拷贝到 `~/.local/share/wallpapers/`，头像通过 `home.file` 设置；DMS 的具体 session 设置由 DMS 自己写入。

6. **NvChad Lua 配置独立仓库** - `nix4nvchad` 继续负责包装 Neovim 和运行时依赖，`nvchad-starter` 跟随 `github:Mooling0602/NvCfg`。主仓库只保留 `programs.nvchad.enable`、`extraPackages` 和 `backup`。

7. **用户名和主机名参数化** - `flake.nix` 的 `let username` 注入到 `my.username`（系统模块）和 `extraSpecialArgs`（Home Manager 模块）。`users.nix`、`desktop.nix`、`home/default.nix` 均通过 `${username}` 或 `${config.my.username}` 引用，消除所有硬编码。

## Niri 配置文件管理

- `~/.config/niri/config.kdl` 和 `~/.config/niri/dms/*.kdl` 是普通可写文件，由 DMS/Niri 在运行时管理
- DMS/Niri 可变配置快照保存在 `user_profiles/mooling/desktop-config/`，仅用于备份和审查
- 需要重新生成时：`echo -e "1\n1-3\n1\ny" | DMS_PRIVESC=sudo dms setup`
- 需要版本化时，从 `~/.config/niri/` 和 `~/.config/DankMaterialShell/` 更新快照，再用 `git diff` 审查并提交

## 已修复的关键问题

| 问题 | 方案 |
|------|------|
| config.kdl 反复冲突 | DMS/Niri 文件不再由 Home Manager 管理 |
| DMS 图形设置只读或重启丢失 | 移除 `programs.dank-material-shell.session` |
| Qt 应用 DMS 启动时 env 错误 | systemd.user.sessionVariables 写入 environment.d |
| Qt 标题栏风格 | `QT_WAYLAND_DECORATION=ssd` 与 `QT_WAYLAND_DISABLE_WINDOWDECORATION=1`，让 niri 提供 SSD |
| Dolphin 右键"打开方式"无应用 | `applications.menu` symlink |
| Greeter 不跟随桌面主题 | `configHome = "/home/mooling"` |
| 蓝牙不可用 | `hardware.bluetooth.enable` |
| 文件选择器走 GNOME | xdg-desktop-portal-kde + portals.conf |
| Alacritty 不跟随浅色/暗色模式 | 导入 DMS 生成的 `dank-theme.toml` |
| DMS 不随系统启动 | 从 niri spawn 切换到 systemd 管理 |
| NVIDIA 驱动 | hardware.nvidia 配置 + Prime offload |
| fcitx5 Wayland 警告 | `waylandFrontend = true` |

## 未解决的问题

- niri 概览中工作区卡片的透明阴影边框 - 来源未定位（不是 shadow、不是 recent-windows、不是 m3Elevation）

## 社区信息

- 参见 https://github.com/AvengeMedia/DankMaterialShell/issues/1788
