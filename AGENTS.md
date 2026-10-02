# AI Agents Rules

## 工作流程

每次修改配置时按此顺序操作：

1. **修改** - 编辑配置文件

2. **提交** - `git commit` 到本地

> 在重建前进行提交，可以避免 `warning: Git tree '/home/mooling/nixos-config' is dirty` 警告和 git 未暂存引发的重建报错。快速验证时 git add . 即可。

3. **重建切换并验证** - `sudo nixos-rebuild switch --flake ~/nixos-config#<hostname>`（`<hostname>` 即 `hosts/` 下的目录名，本机为 `mooling-laptop`），确认无报错

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

6. **NvChad Lua 配置独立仓库** - `nix4nvchad` 继续负责包装 Neovim 和运行时依赖，`nvchad-starter` 跟随 `github:Mooling0602/NvCfg`。主仓库只保留 `programs.nvchad.enable` 和 `extraPackages`。主题在 NvCfg 的 `lua/chadrc.lua` 内静态指定（`catppuccin` / `catppuccin-latte`），不依赖 DMS。`backup = false` - 该模块每次激活都会把 store 配置整体复制到 `~/.config/nvim`，开启备份会按时间戳累积目录（曾达 110 个）；配置已完全声明式管理，无需备份。

7. **用户名和主机名参数化（身份下沉到主机目录）** - `flake.nix` 只枚举 `hosts/` 下的主机目录（目录名即主机名）并通过 `specialArgs` 注入 `hostname`，`nixosConfigurations` 由 `lib.genAttrs` 生成；设备身份写在各自 `hosts/<host>/default.nix` 顶部的 `my.username` / `my.hostname`，多设备共用仓库时不会互相冲突。`modules/system/users.nix`、`hosts/*/nix-builder.nix`、`modules/home/default.nix` 均通过 `${hostname}`（specialArgs）或 `${config.my.username}`（系统模块）引用，`flake.nix` 内不得出现具体用户名或主机名字符串。

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
| Greeter 不跟随桌面主题 | `services.displayManager.dms-greeter.configHome = "/home/${config.my.username}"` |
| 蓝牙不可用 | `hardware.bluetooth.enable` |
| 文件选择器走 GNOME | xdg-desktop-portal-kde + portals.conf |
| 终端配色不跟随系统 | 主题引用单列于 `modules/desktop/<desktop-module>/terminal.nix`；终端程序、字体与通用偏好留在 `modules/home/defaults/terminal.nix`，由 Home Manager 合并两侧配置 |
| DMS 不随系统启动 | 从 niri spawn 切换到 systemd 管理 |
| NVIDIA 驱动 | hardware.nvidia 配置 + Prime offload |
| fcitx5 Wayland 警告 | `waylandFrontend = true` |

## 未解决的问题

- niri 概览中工作区卡片的透明阴影边框 - 来源未定位（不是 shadow、不是 recent-windows、不是 m3Elevation）

## 社区信息

- 参见 https://github.com/AvengeMedia/DankMaterialShell/issues/1788
