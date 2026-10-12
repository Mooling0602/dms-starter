# AI Agents Rules

## 工作流程

每次修改配置时按此顺序操作：

1. **修改**：编辑配置文件

2. **提交**：`git commit` 到本地

> 在重建前进行提交，可以避免 `warning: Git tree '/home/mooling/nixos-config' is dirty` 警告和 git 未暂存引发的重建报错。快速验证时 git add . 即可。

3. **重建切换并验证**：`sudo nixos-rebuild switch --flake ~/nixos-config#<hostname>`（`<hostname>` 即 `hosts/` 下的目录名，本机为 `mooling-laptop`），确认无报错

4. **推送**：`git push`

5. **提交信息格式**：不添加任何 `Co-Authored-By` 之类的尾注，直接以用户身份使用语义化格式提交。

尊重用户自行修改和管理的意愿，只有在用户明确表示无需再行询问时，才直接按上述内容执行操作。

## 代码编辑规范

- **注释语言**：Nix 代码中的注释统一使用英文。文档（Markdown）跟随其当前所用语言，简体中文文档继续使用中文，英文文档继续使用英文。
- **连接符**：减少连接符的使用。需要引出说明或分隔并列内容时，优先使用冒号、逗号或重写为自然语句；确有必要时统一使用半角 `-`，不使用 `—`、`–` 或 `--`。
- 上述范围仅限注释与文档正文。程序生成或备份抓取的内容、命令行参数、代码片段、路径、文件名，以及上游补丁内容中的连字符保持原样。

## 维护清单

- `MAINTENANCE.md` 记录临时构建绕过、外部功能补丁、任何替代上游包源的 fork（不限定所有者）及配置例外的原因、上游链接、移除条件和复查命令。
- 更新 `flake.lock`、相关依赖或覆盖时，可以先检查该清单；上游已修复时删除（或者归档）对应覆盖，并按文档完成验证。

## 关键设计决策

1. **DMS/Niri 运行配置不进行声明式管理**：不声明 `programs.dank-material-shell.session`，也不通过 `xdg.configFile` 或 `mkOutOfStoreSymlink` 挂载 `~/.config/niri/config.kdl` 和 `~/.config/niri/dms/*.kdl`。DMS 拥有自身运行配置和 `~/.config/niri/`，避免图形设置只读或重启后被 Nix 覆盖。

2. **DMS 用 systemd 管理**：`systemd.enable = true`，不用 `niri.enableSpawn`。DMS 崩溃会自动重启。

3. **Qt 环境变量写 environment.d**：`systemd.user.sessionVariables` 同时设置了 `QT_QPA_PLATFORMTHEME=qt6ct` 和 `QT_QPA_PLATFORMTHEME_QT6=qt6ct`，确保 niri 和 DMS 启动的应用都能拿到正确的 Qt 变量。niri 里也设了一份同样的值（`programs.niri.settings.environment`）。两者保持一致。

4. **字体分两级**：系统级 `fonts.packages`（greeter 可见）+ 用户级 `home.packages`（fontconfig 使用）。

5. **壁纸/头像资源仍由 Nix 提供**：壁纸文件通过 `home.file` 拷贝到 `~/.local/share/wallpapers/`，头像通过 `home.file` 设置；DMS 的具体 session 设置由 DMS 自己写入。

6. **NvChad Lua 配置独立仓库**：`nix4nvchad` 继续负责包装 Neovim 和运行时依赖，`nvchad-starter` 跟随 `github:Mooling0602/NvCfg`。主仓库只保留 `programs.nvchad.enable` 和 `extraPackages`。主题在 NvCfg 的 `lua/chadrc.lua` 内静态指定（`catppuccin` / `catppuccin-latte`），不依赖 DMS。`backup = false`：该模块每次激活都会把 store 配置整体复制到 `~/.config/nvim`，开启备份会按时间戳累积目录（曾达 110 个）；配置已完全声明式管理，无需备份。

7. **用户名和主机名参数化（身份下沉到主机目录）**：`flake.nix` 只枚举 `hosts/` 下的主机目录（目录名即主机名）并通过 `specialArgs` 注入 `hostname`，`nixosConfigurations` 由 `lib.genAttrs` 生成；设备身份写在各自 `hosts/<host>/default.nix` 顶部的 `my.username` / `my.hostname`，多设备共用仓库时不会互相冲突。`modules/system/users.nix`、`hosts/*/nix-builder.nix`、`modules/home/default.nix` 均通过 `${hostname}`（specialArgs）或 `${config.my.username}`（系统模块）引用，`flake.nix` 内不得出现具体用户名或主机名字符串。

8. **桌面模块分三层，切换靠 `let` 绑定**：`hosts/<host>/default.nix` 顶部的 `let desktop = "<name>";` 同时决定 `my.desktop` 的值与 `imports` 中 `./desktop/${desktop}/default.nix` 的路径；该目录再导入 `modules/desktop/<name>/` 下的实现（系统层 `system.nix` + Home Manager 层 `default.nix`）。**必须用 `let` 而非 `config.my.desktop`**：`imports` 求值早于 `config`，引用 `config` 会导致无限递归。一致性校验由**实现模块自己直接断言**：`modules/desktop/<name>/system.nix` 断言 `config.my.desktop == baseNameOf ./.`（即实现所在目录名），两侧来源独立（一处是 host 文件手写的 `let` 绑定，一处是文件实际所在目录），因此在任何主机上都通用，且重命名实现目录后自动跟随、无需手工同步。另由 `modules/system/config.nix` 用 `my.desktopImplementationLoaded` 兜底断言「至少加载了一个实现」，覆盖漏导入实现时连实现侧断言都不存在的情况。

9. **桌面专属的 Home Manager 配置由桌面层用 `home-manager.sharedModules` 挂载**：桌面无关的 HM 模块才放在全局接线模块 `modules/core.nix` 的 `home-manager.users.<name>.imports` 里（原位于 `flake.nix`，分拆后接线由 `modules/core.nix` 承接）。**禁止**把 DMS 生态的模块（`dms.homeModules.dank-material-shell`、`danksearch`、`dankcalendar`）或桌面专属的 `home.activation` 步骤写进 `modules/core.nix`，否则切换桌面后仍然生效（曾导致 KDE 下残留 `dms.service`、`dsearch.service`、`fcitx5-dms-theme-sync` 及 `restoreDesktopConfig` 激活步骤）。系统层模块经 `specialArgs` 拿到 `inputs`，可直接引用自己桌面所需的 input，无需在 `modules/core.nix` 为该桌面加 overlay 或 `extraSpecialArgs`。

10. **Noctalia 桌面层：外观声明式，niri 配置按会话隔离**：`modules/desktop/noctalia-with-niri/` 的 shell、登录器与模块都来自锁定 nixpkgs（`noctalia` 5.2.1 + `services.displayManager.noctalia-greeter`），不新增 flake input。外观（头像、壁纸、配色与应用配色模板）由 `programs.noctalia.settings` 声明进 `~/.config/noctalia/config.toml`：Noctalia 先读该目录的 `*.toml`、最后读界面写入的 `settings.toml`，因此声明默认值不会挡住在图形界面里修改，这与决策 1 的「DMS 拥有运行配置」并不冲突。niri 侧不再共用 DMS 的 `~/.config/niri/config.kdl`：本层声明 `~/.config/niri-noctalia/config.kdl`，并用 `systemd.user.services.niri` 的 drop-in 把 `NIRI_CONFIG` 指过去。`gtk.enable` 与 `qt.enable` 仍不启用，因为模板渲染出的应用配色文件必须保持可写。细节见「noctalia-with-niri 桌面层」。

## Niri 配置文件管理

- `~/.config/niri/config.kdl` 和 `~/.config/niri/dms/*.kdl` 是普通可写文件，由 DMS/Niri 在运行时管理
- DMS/Niri 可变配置快照保存在 `user_profiles/mooling/desktop-config/`，仅用于备份和审查
- 需要重新生成时：`echo -e "1\n1-3\n1\ny" | DMS_PRIVESC=sudo dms setup`
- 需要版本化时，从 `~/.config/niri/` 和 `~/.config/DankMaterialShell/` 更新快照，再用 `git diff` 审查并提交

## noctalia-with-niri 桌面层

`modules/desktop/noctalia-with-niri/` 是与 `dms-with-niri` 并列的备用桌面层，已就绪但尚未在任何主机上启用。`hosts/vmware/desktop/noctalia-with-niri/default.nix` 已经放好，启用只需改 `hosts/<host>/default.nix` 顶部的 `let desktop`。

### 组成与来源

- shell：锁定 nixpkgs 里的 `noctalia` 5.2.1（C++ 写的 v5，不是 Quickshell 的 v4 `noctalia-shell`），cache.nixos.org 已缓存，不需要本地编译。
- 登录器：`services.displayManager.noctalia-greeter`（nixpkgs 1.6.0），切换到该层后不再依赖 DMS 生态；`greeter` 用户由 greetd 模块创建，不需要 `dms-greeter` 那样的额外组。
- 两者都不新增 flake input。没有采用上游 flake 的 cachix 缓存：官方说明 `inputs.nixpkgs.follows` 会改变推导哈希、导致缓存失效，而缓存命中正是选 nixpkgs 版本的理由。

### 配置分层与外观

Noctalia 按目录读配置：`~/.config/noctalia/*.toml` 先读，界面写入的 `settings.toml` 最后读并覆盖。所以 `programs.noctalia.settings`（Home Manager 生成只读的 `config.toml`）既能声明默认外观，也不会挡住图形设置菜单（这一条与最初「保持为空」的判断相反，已按上游文档更正）。

声明内容集中在 `modules/desktop/noctalia-with-niri/default.nix`：

- 头像：`shell.avatar_path = "~/.face"`，即 `modules/home/mooling/avatar.nix` 安装的文件。Noctalia 会同时更新 AccountsService 的 `IconFile`，`noctalia-greeter` 因此复用同一张头像。
- 壁纸：`enabled` + `directory = "~/.local/share/wallpapers"`（`modules/home/defaults/theme.nix` 放置的深浅两张），默认取深色那张，与 `theme.mode = "dark"` 对齐。
- 配色：`source = "wallpaper"` 加 `wallpaper_scheme = "m3-content"`，沿用 DMS 时期由壁纸生成调色板的方式；想固定调色板就改成 `source = "builtin"` 与调色板名。
- 应用配色模板：`alacritty`、`kitty`、`ghostty`（对应 `terminal.nix` 声明的 include：三个模板的 apply 钩子检测到 include 已存在就不改配置，所以不会去写 HM 的只读符号链接）、`gtk3`、`gtk4`、`qt`、`kcolorscheme`。
- **故意不启用 `niri` 模板**：它除渲染 `noctalia.kdl` 外，还会往 DMS 独占的 `~/.config/niri/config.kdl` 追一行 include，切回 DMS 后会盖掉 DMS 自己的配色。本层已用绝对路径 include 渲染结果，代价仅是 niri 自身的 focus-ring 与边框颜色保持默认。

仍由运行时可写、不由 Home Manager 占用的文件：模板渲染出的 `~/.config/gtk-{3,4}.0/noctalia.css`、`~/.config/qt{5,6}ct/colors/noctalia.conf`、终端的 `noctalia*` 主题文件，以及 DMS 拥有的 `~/.config/niri/`。`gtk.enable` 与 `qt.enable` 因此都不启用：后者会把 Qt 模板配色方案旁边的 `~/.config/qt6ct/qt6ct.conf` 换成只读符号链接，界面里就选不了 Noctalia 配色。

### 会话与切换

- shell 由 `programs.noctalia.systemd.enable` 的用户服务拉起，target 是 `graphical-session.target`（niri 会话会启动它），所以不需要 niri 的 `spawn-at-startup`：niri 配置之所以声明式，是为了配置隔离，不是因为启动 shell。
- 锁屏走 PAM 的 `login` 服务，没有独立的 PAM service 可挂钩。`modules/optional/howdy.nix` 出于解锁 GNOME Keyring 的考虑在 `login` 上禁用了 Howdy，因此 Noctalia 的锁屏一律要求密码；恢复人脸认证会连带影响 greeter。

### niri 配置隔离

两个桌面模块此前共用 `~/.config/niri/config.kdl`，切桌面会互相留下 include 与键位。现在按会话隔离：

- niri 支持 `-c/--config` 与 `NIRI_CONFIG` 环境变量。本层在 `system.nix` 里给 `systemd.user.services.niri` 加 drop-in（`environment.NIRI_CONFIG`），指向 `~/.config/niri-noctalia/config.kdl`；`dms-with-niri` 完全不设该变量，继续读默认路径。一次会话只读一个配置，两个桌面互不读写。
- 本层配置是声明式的：`modules/desktop/noctalia-with-niri/niri-config.kdl`（真实 KDL，便于 review 与 `niri validate`）。`niri.nix` 在构建期用一个 `runCommand` 把 include 注释掉后跑 `niri validate`，语法错误在构建阶段就暴露。占位符 `@REGION_RECORD@` 与 `@NIRI_INPUT_PORTAL@` 在构建时替换为实际路径，文件本身不含用户名或主机名。
- 主机专属设置走 `include "host.kdl"`：放在配置最后，因此覆盖共享默认值。`hosts/vmware/desktop/noctalia-with-niri/niri-host.kdl` 给出 `Virtual-1` 的 mode/scale，同目录的 `niri-host.nix` 通过 `home-manager.sharedModules` 用 `lib.mkForce` 覆盖层里那份空默认文件（host 桌面目录是作为系统模块导入的，不能直接设 HM 选项）。相对 include 按软链所在目录解析（已实测），所以 HM 安装到 store 不影响它。
- Noctalia 的配色文件由上游固定写在 `~/.config/niri/noctalia.kdl`，本层用 `include "~/.config/niri/noctalia.kdl"` 引用。niri 把读不到的 include 当致命错误，所以 `home.activation.noctaliaNiriThemeStub` 在文件不存在时先放一个空占位，之后交给 shell 渲染。
- 手动命令与嵌套运行的 niri 不经过该单元，默认仍读 `~/.config/niri/config.kdl`，需要时自行加 `-c`。切换后可用 `journalctl --user -u niri | grep "loaded config"` 与 `systemctl --user show niri.service -p Environment` 确认读到的是哪个文件。

### 从 DMS 层移植时的取舍

| DMS 层的部分 | 在 noctalia 层的处置 |
|---|---|
| `packages.nix` 的 `xwayland-satellite` | 保留。niri 自身会 spawn 它（二进制内含该集成），与 shell 无关。 |
| `xdg-portals.nix` 的门户路由、Settings 提供方剔除、`niri-input-portal` 单元 | 保留。全部属于 niri/KDE/GNOME 层；`MAINTENANCE.md` 对应两条目的「位置」已补上本层路径。 |
| `terminal.nix` 引用 matugen 生成的配色 | 改写：alacritty 用 `themes/noctalia.toml`、kitty 用 `include themes/noctalia.conf`、ghostty 用 `theme = noctalia`。 |
| `ui.nix` 的 Qt 会话变量 | 保留，取值与 DMS 层一致；但不再启用 `qt.enable`。 |
| `ui.nix` 的可写 `adw-gtk3` 副本 | 只保留 `adw-gtk3` 包本身。Noctalia 仅导入 `noctalia.css` 并切换 gtk-theme，不像 DMS 那样原地改样式表；store 中的主题经 `XDG_DATA_DIRS`（含 `/etc/profiles/per-user/<user>/share`）即可被发现，`MAINTENANCE.md` 那条仍只属于 DMS。 |
| `fcitx-theme-sync.nix` | 未移植，见下方缺口。 |
| `backup.nix` 的 DMS/Niri 快照自动恢复 | 未移植，见下方缺口。 |
| `security.pam.services.dankshell` 与 Howdy 联动 | 不需要。Noctalia 走 PAM 的 `login` 服务，理由见上。 |
| `services.displayManager.dms-greeter` 与用户的 `dms-greeter` 组 | 换成 `noctalia-greeter`；`greeter` 用户由 greetd 模块创建，不再需要额外组。 |
| `system.nix` 的 gpu-screen-recorder polkit 规则 | 未移植，见下方缺口。 |

### 尚未处理的缺口

- **gpu-screen-recorder 的免密码 polkit 规则**只在 `dms-with-niri` 的 `system.nix` 里。运行时 niri 快捷键调用的 `/home/mooling/.local/bin/region-record` 使用 gpu-screen-recorder，切到 noctalia 后录屏会每次索要密码。该规则与 shell 无关，宜移到共享的系统模块，而不是在新层复制一份。
- **`fcitx-theme-sync.nix`** 读 DMS 自己的 `~/.local/share/color-schemes/DankMatugen.colors`，而 Noctalia 没有 fcitx5 模板。若要恢复候选窗跟随深浅色，可先启用 `kcolorscheme` 模板（输出 `~/.local/share/color-schemes/noctalia.colors`），再让同步脚本改读该文件。
- **`backup.nix` 的快照自动恢复**：`user_profiles/mooling/desktop-config/` 仍是 DMS 形态（`settings.json` 等），Noctalia 侧没有对应快照；niri 部分仍可用 `scripts/backup.sh` 手工恢复。

### 切换后待确认

Noctalia 自带 polkit 认证代理，niri-flake 也会拉起 `niri-flake-polkit`（`wantedBy = [ "niri.service" ]`），两者只有一个能持有 `org.freedesktop.PolicyKit1.AuthenticationAgent`。切换后用 `systemctl --user status niri-flake-polkit` 确认；若它反复重启，就在本层 `system.nix` 里停用该单元。

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

- niri 概览中工作区卡片的透明阴影边框：来源未定位（不是 shadow、不是 recent-windows、不是 m3Elevation）

## 社区信息

- 参见 https://github.com/AvengeMedia/DankMaterialShell/issues/1788
