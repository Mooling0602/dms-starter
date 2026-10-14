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

10. **Noctalia 桌面层：外观声明式，niri 配置按会话隔离**：`modules/desktop/noctalia-with-niri/` 的 shell、登录器与模块都来自锁定 nixpkgs（`noctalia` 5.2.1 + `services.displayManager.dms-greeter`，后者因为它跑在 niri 里，而 `noctalia-greeter` 的 wlroots 合成器在这台 VM 上不可用），不新增 flake input。外观（头像、壁纸、配色与应用配色模板）由 `programs.noctalia.settings` 声明进 `~/.config/noctalia/config.toml`：Noctalia 先读该目录的 `*.toml`、最后读界面写入的 `~/.local/state/noctalia/settings.toml`，因此声明默认值不会挡住在图形界面里修改，这与决策 1 的「DMS 拥有运行配置」并不冲突。niri 侧不再共用 DMS 的 `~/.config/niri/config.kdl`：本层声明 `~/.config/niri-noctalia/config.kdl`，并用 `systemd.user.services.niri` 的 drop-in 把 `NIRI_CONFIG` 指过去。`gtk.enable` 与 `qt.enable` 仍不启用，因为模板渲染出的应用配色文件必须保持可写。深浅色按日出日落自动切换：`theme.mode = "auto"` 配 `theme-auto.nix` 里的固定坐标（不联网、不出网到机房），壁纸图另由该文件的钩子跟随模式切换，因为 Noctalia 只翻转调色板，不会重新应用壁纸。细节见「noctalia-with-niri 桌面层」。

## Niri 配置文件管理

- `~/.config/niri/config.kdl` 和 `~/.config/niri/dms/*.kdl` 是普通可写文件，由 DMS/Niri 在运行时管理
- DMS/Niri 可变配置快照保存在 `user_profiles/mooling/desktop-config/`，仅用于备份和审查
- Noctalia 层的 niri 配置是声明式的，例外只有可写的 `~/.config/niri-noctalia/custom.kdl`，它单独往返于 `user_profiles/mooling/niri-noctalia/`，详见「niri 配置隔离」
- 需要重新生成时：`echo -e "1\n1-3\n1\ny" | DMS_PRIVESC=sudo dms setup`
- 需要版本化时，从 `~/.config/niri/` 和 `~/.config/DankMaterialShell/` 更新快照，再用 `git diff` 审查并提交

## noctalia-with-niri 桌面层

`modules/desktop/noctalia-with-niri/` 是与 `dms-with-niri` 并列的桌面层，目前已在 `hosts/vmware` 与 `hosts/mooling-laptop` 上启用（其它主机切换只需改 `hosts/<host>/default.nix` 顶部的 `let desktop`，并在 `hosts/<host>/desktop/noctalia-with-niri/` 准备同名目录）。

### 组成与来源

- shell：锁定 nixpkgs 里的 `noctalia` 5.2.1（C++ 写的 v5，不是 Quickshell 的 v4 `noctalia-shell`），cache.nixos.org 已缓存，不需要本地编译。
- 登录器：`services.displayManager.dms-greeter`（nixpkgs 自带模块，界面跑在 niri 里，并用 `configHome` 复用 `~/.config/DankMaterialShell` 的既有外观）。原本计划用 `noctalia-greeter`，但它自带的 wlroots 合成器在这台 VM 的 vmwgfx 上不可用，两次绕过均失败，原因与证据见 `MAINTENANCE.md`。
- 两者都不新增 flake input。没有采用上游 flake 的 cachix 缓存：官方说明 `inputs.nixpkgs.follows` 会改变推导哈希、导致缓存失效，而缓存命中正是选 nixpkgs 版本的理由。

### 配置分层与外观

Noctalia 按目录读配置：`~/.config/noctalia/*.toml` 先读，界面写入的 `~/.local/state/noctalia/settings.toml` 最后读并覆盖。所以 `programs.noctalia.settings`（Home Manager 生成只读的 `config.toml`）既能声明默认外观，也不会挡住图形设置菜单（这一条与最初「保持为空」的判断相反，已按上游文档更正）。

声明内容集中在 `modules/desktop/noctalia-with-niri/default.nix`（深浅色切换所需的坐标与钩子在同目录的 `theme-auto.nix`，理由见下节）：

- 头像：`shell.avatar_path = "~/.face"`，即 `modules/home/mooling/avatar.nix` 安装的文件。Noctalia 会同时更新 AccountsService 的 `IconFile`，其它读 AccountsService 的组件（如登录界面）可复用同一张头像。
- 壁纸：`enabled` + `directory = "~/.local/share/wallpapers"`（`modules/home/defaults/theme.nix` 放置的深浅两张）。`wallpaper.default.path` 指向深色那张，但它只是首次启动的种子：实际显示哪张由 `theme-auto.nix` 的钩子按当前模式挑选（见下）。
- 配色：`source = "wallpaper"` 加 `wallpaper_scheme = "m3-content"`，沿用 DMS 时期由壁纸生成调色板的方式；想固定调色板就改成 `source = "builtin"` 与调色板名。
- **深浅色随日出日落自动切换**：`theme.mode = "auto"`，坐标由 `theme-auto.nix` 声明（见下）。`shell_mode` 默认 `follow`，所以状态栏、各应用配色模板与壁纸一起翻转。
- 应用配色模板：`alacritty`、`kitty`、`ghostty`（对应 `terminal.nix` 声明的 include：三个模板的 apply 钩子检测到 include 已存在就不改配置，所以不会去写 HM 的只读符号链接）、`gtk3`、`gtk4`、`qt`、`kcolorscheme`。其中 `kcolorscheme` 的输出 `~/.local/share/color-schemes/noctalia.colors` 同时是 fcitx5 候选窗同步脚本的数据源（上游没有 fcitx5 模板，见下面的移植取舍表）。
- **`niri` 内置模板仍不启用，改用等价的自定义模板**：内置模板除渲染 `noctalia.kdl` 外，还会往 DMS 独占的 `~/.config/niri/config.kdl` 追一行 include，切回 DMS 后会盖掉 DMS 自己的配色，且它的输出目录固定。本层把该模板的载荷复制为 `niri-palette.kdl`，声明为自定义模板 `niri-colors`（`input_path` 相对路径落在 `~/.config/noctalia/`，`output_path` 指向本层自己的 `~/.config/niri-noctalia/noctalia.kdl`），不带任何 hook。niri 的 focus-ring、窗口边框、tab-indicator 与 recent-windows 高亮因此跟随配色（默认值是 `#7fc8ff` / `#505050` / `#9b0000`，未同步时一眼可辨）。

仍由运行时可写、不由 Home Manager 占用的文件：模板渲染出的 `~/.config/gtk-{3,4}.0/noctalia.css`、`~/.config/qt{5,6}ct/colors/noctalia.conf`、终端的 `noctalia*` 主题文件，以及 DMS 拥有的 `~/.config/niri/`。`gtk.enable` 与 `qt.enable` 因此都不启用：后者会把 Qt 模板配色方案旁边的 `~/.config/qt6ct/qt6ct.conf` 换成只读符号链接，界面里就选不了 Noctalia 配色。

### 深浅色自动切换

`theme-auto.nix` 是本层唯一不在 `default.nix` 里的外观声明，拆出来是为了让那段钩子脚本与坐标说明不淹没在模板清单里。它做两件事：

- **坐标**：`latitude = 27.9494`、`longitude = 116.3582`（江西抚州）。Noctalia 解析 `auto` 的优先级是 `auto_locate`（按 IP 定位）、非空 `address`（地理编码）、手填坐标，前两者都要联网，而 VM 的出口 IP 会定位到机房，因此固定坐标：离线可用、可复现。`custom_schedule` 保持关闭，开启它必须同时给出 `sunset` 与 `sunrise` 两个 `HH:MM`，否则 `noctalia config validate` 会判为配置错误；用坐标时日出日落由本机天文算法算出，无需网络。
- **钩子**：`hooks.started` 与 `hooks.theme_mode_changed` 指向同一个脚本。Noctalia 只会翻转自己的调色板，不会重新应用壁纸图（选图只发生在选择器、`switchWallpaperTo()` 和可选的轮播里，而 `directory_light`／`directory_dark` 只影响挑图时的目录），所以深浅两张图由这个脚本按模式切换。
  - 脚本调用 `noctalia msg theme-mode-get` 取**已解析**的模式（只会返回 `light` 或 `dark`，即使配置的是 `auto`），再与 `noctalia msg wallpaper-get` 比对，路径一致就直接退出：`wallpaper-set` 本身对相同路径会提前返回，这里只是省掉一次往返、不去碰 `settings.toml`。
  - `theme_mode_changed` 不会在启动时触发：该钩子有「已知上一个模式」的前置条件，首次解析时尚未有上一个模式，所以必须用 `started` 补上登录时的同步，否则白天登录会一直停留声明的深色种子直到下一个日落。
  - 钩子经 `/bin/sh -lc` 运行，`theme_mode_changed` 会把 `NOCTALIA_THEME_MODE` 放进环境（管理器在 fork 之后才清除它，因此子进程读得到），脚本把它当作快路径；`started` 不带任何环境变量，所以两条路径最终都回落到查询运行中的 shell。
  - `noctalia` 用 store 绝对路径调用（`${pkgs.noctalia}/bin/noctalia`），不依赖钩子继承到的 `PATH`。
- **已知取舍**：`wallpaper-set` 会把结果写进 `~/.local/state/noctalia/settings.toml`，所以在图形界面手动选的壁纸会在下一次模式翻转时被覆盖。这是选择「用钩子强制切换」时接受的代价；不接受时只能放弃自动换图。
- **核对**：`noctalia msg theme-mode-get` 应返回当前解析结果，`noctalia config export | grep -A 3 '^\[location\]'` 应显示上述坐标。注意 `~/.local/state/noctalia/settings.toml` 里若残留 `[theme] mode = "dark"`，会盖过 `config.toml` 的 `auto`（旧版本装过的手动覆盖），用 `noctalia msg theme-mode-set auto` 或在界面里改一次即可。

### 会话与切换

- shell 由 `programs.noctalia.systemd.enable` 的用户服务拉起，target 是 `graphical-session.target`（niri 会话会启动它），所以不需要 niri 的 `spawn-at-startup`：niri 配置之所以声明式，是为了配置隔离，不是因为启动 shell。
- 锁屏走 PAM 的 `login` 服务，没有独立的 PAM service 可挂钩。`modules/optional/howdy.nix` 出于解锁 GNOME Keyring 的考虑在 `login` 上禁用了 Howdy，因此 Noctalia 的锁屏一律要求密码；恢复人脸认证会连带影响 greeter。
- **登录器不能用 noctalia-greeter**：它自带的 wlroots 合成器无法在 VMware vmwgfx 上处理客户端 dmabuf 缓冲（对 GBM 已关闭的 GEM handle 重复 close，vmwgfx 返回 `EINVAL`），合成器随后向客户端报协议错误、greeter 退出而 greetd 不重试，表现为黑屏；两次绕过（扫描输出与修饰符开关、pixman 加软件 GL）都无效。现改用 `dms-greeter`（界面跑在 niri 里，niri 基于 smithay，在这台 GPU 上正常），并保留 `getty@tty2` 作逃生通道：模板实例单元必须同时声明 `wantedBy = [ "getty.target" ]`，只设 `enable` 不会启动。详见 `MAINTENANCE.md`。

### niri 配置隔离

两个桌面模块此前共用 `~/.config/niri/config.kdl`，切桌面会互相留下 include 与键位。现在按会话隔离：

- niri 支持 `-c/--config` 与 `NIRI_CONFIG` 环境变量。本层在 `system.nix` 里给 `systemd.user.services.niri` 加 drop-in（`environment.NIRI_CONFIG`），指向 `~/.config/niri-noctalia/config.kdl`；`dms-with-niri` 完全不设该变量，继续读默认路径。一次会话只读一个配置，两个桌面互不读写。
- 本层配置是声明式的：`modules/desktop/noctalia-with-niri/niri-config.kdl`（真实 KDL，便于 review 与 `niri validate`）。`niri.nix` 在构建期把该配置与渲染后的配色一起放进一个临时目录跑 `niri validate`：相对 include 按 niri 收到的那条路径所在目录解析（已用软链实测：软链目录生效，而不是 store 里的真实文件所在目录），临时目录正是两者运行时的位置，所以校验的是真实的 include 行。配色用 `noctalia theme` 现场渲染，占位符写错或注释里混入花括号都会在构建阶段暴露。占位符 `@REGION_RECORD@` 与 `@NIRI_INPUT_PORTAL@` 在构建时替换为实际路径，文件本身不含用户名或主机名。
- 主机专属设置走 `include "host.kdl"`：放在共享默认值之后，因此覆盖共享默认值（其后还有一枚手工覆盖文件，见下条）。`hosts/vmware/desktop/noctalia-with-niri/niri-host.kdl` 给出 `Virtual-1` 的 mode/scale，同目录的 `niri-host.nix` 通过 `home-manager.sharedModules` 用 `lib.mkForce` 覆盖层里那份空默认文件（host 桌面目录是作为系统模块导入的，不能直接设 HM 选项）。
- 配色走 `include "noctalia.kdl" optional=true`，指向本层目录下由自定义模板渲染的同名文件，不再碰 DMS 的 `~/.config/niri/`。`optional=true` 让文件尚未渲染时 niri 只警告、不致命；niri 也会持续监视这个缺失的可选 include，文件一旦出现就自动重载，因此不再需要 `home.activation` 写占位文件。构建期额外断言「两个文件都已就位时不得出现 `optional include not found`」，避免 include 名与模板 `output_path` 改歪后无声退回默认配色（可选 include 缺失只警告、退出码仍为 0）。
- 需要注意：模板没有 `undo_hook` 之类的机制，Noctalia 不会删除 `~/.config/niri-noctalia/noctalia.kdl`。切回 `dms-with-niri` 时该文件会成为残留，但 DMS 不设 `NIRI_CONFIG`、读的是自己的 `~/.config/niri/config.kdl`，而配色文件里的 `layout { border { ... } }` 只改颜色、不会打开边框（niri 只在主配置里出现 `border` 时才启用边框），所以残留是惰性的；仍建议切换后手动删除。
- **手工叠加修改走 `include "custom.kdl" optional=true`，放在两个 include 之后**：`~/.config/niri-noctalia/custom.kdl` 是唯一可写的 KDL，用来叠加声明层不打算覆盖的临时偏好。它**不能**放进 `xdg.configFile`（那会变成只读 store 符号链接），改为由 `niri.nix` 的 `home.activation.seedNiriCustomConfig` 在文件缺失时播种一份带注释的模板 `niri-custom-default.kdl`，之后不再改写，删掉即可恢复模板。构建期把这份模板一并 stage 进校验目录，所以模板自身的语法错误也会在构建阶段拦下。模板末尾保留一枚空的 `layout {` `}`，因为图形编辑器把注释挂到已解析的节点上，一个节点都没有的文件首次保存会丢掉全部注释；该空块解析后不含任何属性，纯惰性。
- **图形化编辑走 NiriMod，命令默认就指向这个可写文件**：Noctalia 没有窗口规则编辑器，上游已把相关请求判为不做（`MAINTENANCE.md`）。本层把 `pkgs.nirimod` 覆盖一层 `makeWrapperArgs`，注入 `--config=$XDG_CONFIG_HOME/niri-noctalia/custom.kdl`，所以无论命令行还是桌面项启动的都是同一份包装脚本，保存时改的是 `custom.kdl` 而不是只读的 `config.kdl`。传参不要用 `lib.escapeShellArg` 加引号：`makeWrapper` 把 `--add-flags` 的值原样交给程序，字面引号会被 GLib 当成位置参数丢掉；注入参数排在用户参数之前，而 GLib 对重复选项取最后一个，所以 `nirimod -c other.kdl` 仍可临时改目标。图形界面里只会看到 `custom.kdl` 自己的节点（不显示声明层的规则），这正是预期的范围。
- 叠加能改到什么程度受 niri 的合并语义限制，写进 `custom.kdl` 前需要知道：`input`、`cursor`、`layout`、`debug` 等按属性级合并，可只写要改的项；但 `input` 下的 `touchpad`、`mouse`、`trackpoint`、`trackball` 与 `keyboard` 的 `xkb` 是**整块替换**，只写 `touchpad { tap }` 会丢掉该块其余设置。`binds` 按**按键**覆盖而非整块替换，冲突的键被新值取代、其余键保留，所以只写要改的那几个键就够（`Mod+X` 与 `Super+X` 在运行时是同一个键：`Mod` 解析为 `COMPOSITOR`，niri 再与 `mod-key` 求并，因此 `Super+X` 会静默盖掉 `Mod+X`；同一个文件里出现两个 `binds` 块仍是硬错误）；`environment` 追加、同名后者胜出；`screenshot-path` 取最后一次出现的值；`window-rule`、`layer-rule` 按出现顺序追加并叠加，而 `output` 与 `workspace` 虽然也追加，运行时却取**第一条匹配**：同名 `output` 块不会覆盖 `host.kdl`，要改得直接改 host 文件。
- 失败行为在启动与重载时不同：`custom.kdl` 缺失只警告、不致命；文件存在却语法错误则 `niri validate` 退出码为 1（`optional=true` 也挡不住），热重载会保留当前配置并弹出提示，但下次登录会退回 niri 内置默认配置，等于丢掉整个声明层。因此改动后应先 `niri validate -c ~/.config/niri-noctalia/config.kdl` 再重启会话。
- `custom.kdl` 的备份往返：`./scripts/backup.sh niri-custom-snapshot mooling` 抓取到 `user_profiles/mooling/niri-noctalia/custom.kdl`，`niri-custom-apply` 覆盖回机器。恢复前会在临时目录里连同真实的 `config.kdl`、`host.kdl`、`noctalia.kdl` 一起跑 `niri validate`（文件用 `-L` 复制，否则符号链接会校验错路径），校验不过直接拒绝，避免写坏配置导致下次登录退回默认。
- 手动命令与嵌套运行的 niri 不经过该单元，默认仍读 `~/.config/niri/config.kdl`，需要时自行加 `-c`。切换后可用 `journalctl --user -u niri | grep "loaded config"` 与 `systemctl --user show niri.service -p Environment` 确认读到的是哪个文件。

### 从 DMS 层移植时的取舍

| DMS 层的部分 | 在 noctalia 层的处置 |
|---|---|
| `packages.nix` 的 `xwayland-satellite` | 保留。niri 自身会 spawn 它（二进制内含该集成），与 shell 无关。 |
| `xdg-portals.nix` 的门户路由、Settings 提供方剔除、`niri-input-portal` 单元 | 保留。全部属于 niri/KDE/GNOME 层；`MAINTENANCE.md` 对应两条目的「位置」已补上本层路径。 |
| `terminal.nix` 引用 matugen 生成的配色 | 改写：alacritty 用 `themes/noctalia.toml`、kitty 用 `include themes/noctalia.conf`、ghostty 用 `theme = noctalia`。 |
| `ui.nix` 的 Qt 会话变量 | 保留，取值与 DMS 层一致；但不再启用 `qt.enable`。 |
| `ui.nix` 的可写 `adw-gtk3` 副本 | 只保留 `adw-gtk3` 包本身。Noctalia 仅导入 `noctalia.css` 并切换 gtk-theme，不像 DMS 那样原地改样式表；store 中的主题经 `XDG_DATA_DIRS`（含 `/etc/profiles/per-user/<user>/share`）即可被发现，`MAINTENANCE.md` 那条仍只属于 DMS。 |
| `fcitx-theme-sync.nix` | 移植：数据源改用 Noctalia 的 KColorScheme 模板输出（`~/.local/share/color-schemes/noctalia.colors`），生成的 fcitx 主题目录沿用 `classicui.conf` 里固定的 `dms-plasma` 名字，详见 `MAINTENANCE.md`。 |
| `backup.nix` 的 DMS/Niri 快照自动恢复 | 未移植，见下方缺口。 |
| `security.pam.services.dankshell` 与 Howdy 联动 | 不需要。Noctalia 走 PAM 的 `login` 服务，理由见上。 |
| `services.displayManager.dms-greeter` 与用户的 `dms-greeter` 组 | 保留：它是这台 VM 上唯一能用的登录器（跑在 niri 里），并用 `configHome` 复用 DankMaterialShell 外观；`noctalia-greeter` 不可用，原因见缺口与 `MAINTENANCE.md`。 |
| `system.nix` 的 gpu-screen-recorder polkit 规则 | 在本层复制一份（内容与 DMS 层一致）。每个主机只加载一个桌面实现，两份规则不会同时生效；放在本层可以让规则随桌面一起消失，而不是泄漏给所有桌面。 |

### 尚未处理的缺口

- **`backup.nix` 的快照自动恢复**：`user_profiles/mooling/desktop-config/` 仍是 DMS 形态（`settings.json` 等），Noctalia 侧没有对应快照，也没有与 `restoreDesktopConfig` 对应的自动恢复激活步骤（本层唯一可写的 KDL 是 `custom.kdl`，它由 `seedNiriCustomConfig` 播种、不参与自动恢复）。niri 侧的手工往返可用 `scripts/backup.sh niri-custom-snapshot` 与 `niri-custom-apply`；若将来要把 Noctalia 外观也纳入快照，需要新开一个与 `desktop-config` 并列的组件目录，不要去改 DMS 形态的那份。

### 认证代理与会话核对

- **polkit 认证代理由 Noctalia 自带，上游默认关闭**：`shell.polkit_agent` 默认 `false`，本层在 `default.nix` 里显式开启。本层没有导入 niri-flake 的 Home Manager 模块，所以不存在 `niri-flake-polkit` 单元，也没有第二个候选代理，会话里的图形授权全部由它回答。核对命令：`noctalia config export | grep polkit` 应包含 `polkit_agent = true`，且 `journalctl --user -u noctalia | grep polkit` 应出现 `registered Polkit authentication agent at /org/noctalia/PolkitAuthenticationAgent` 与 `polkit authentication agent active`。注意代理不占用系统总线上的知名名字：`busctl --system ... GetNameOwner s org.freedesktop.PolicyKit1.AuthenticationAgent` 会答 `The name does not have an owner`，它是经 Authority 的注册接口挂上去的，判断代理是否存在要看日志而不是这个名字。图形设置里仍可在 Security 分组关闭它，界面写的是 `~/.local/state/noctalia/settings.toml`，优先级高于本层的 `config.toml`。
- **免密录屏依赖 setuid 的 pkexec**：`gpu-screen-recorder` 的 nixpkgs wrapper 把 `/run/wrappers/bin` 前置进 `PATH` 并用 `pkexec` 提权启动 `gsr-kms-server`，所以两个桌面层的免密规则只有在 pkexec 存在时才会被 polkit 询问到。该 wrapper 在这个 nixpkgs 里默认关闭，本仓库在共享系统模块 `modules/system/polkit.nix` 显式打开，原因、移除条件与复查方法见 `MAINTENANCE.md`。gsr 只支持 NVIDIA/AMD/Intel：`hosts/vmware` 上它以 `unknown gpu vendor: VMware, Inc.` 直接退出，这条链路只能在有真实 GPU 的主机上验证。
- 登录后可用三条命令核对本次会话：`journalctl --user -u niri | grep "loaded config"` 应为 `~/.config/niri-noctalia/config.kdl`；`systemctl --user show niri.service -p Environment` 应含 `NIRI_CONFIG`；`systemctl --user status noctalia.service` 应为 active。

## 已修复的关键问题

| 问题 | 方案 |
|------|------|
| config.kdl 反复冲突 | DMS/Niri 文件不再由 Home Manager 管理 |
| DMS 图形设置只读或重启丢失 | 移除 `programs.dank-material-shell.session` |
| Qt 应用 DMS 启动时 env 错误 | systemd.user.sessionVariables 写入 environment.d |
| Qt 标题栏风格 | `QT_WAYLAND_DECORATION=ssd` 与 `QT_WAYLAND_DISABLE_WINDOWDECORATION=1`，让 niri 提供 SSD |
| Dolphin 右键"打开方式"无应用 | `applications.menu` symlink |
| Greeter 不跟随桌面主题 | `services.displayManager.dms-greeter.configHome = "/home/${config.my.username}"` |
| 切到 Noctalia 后图形授权弹不出认证框 | 开启 Noctalia 自带的 polkit 代理（`shell.polkit_agent = true`） |
| 免密录屏规则因缺 `pkexec` 而空转 | 共享系统模块 `modules/system/polkit.nix` 打开 `security.polkit.enablePkexecWrapper`，恢复 gsr 的提权链路（见 `MAINTENANCE.md`） |
| fcitx5 候选窗不跟随 Noctalia 配色 | 本层移植 DMS 的同步脚本，数据源换成本层 `kcolorscheme` 模板的输出 `~/.local/share/color-schemes/noctalia.colors`（上游没有 fcitx5 模板） |
| fcitx5 选中候选词文字对比度过低 | 两层的同步脚本此前把 `HighlightCandidateColor` 覆盖成选择前景色，而选中项背后是 30% alpha 的高亮位图，实测最低仅 `1.7:1`；改为复用生成器算好的 `NormalColor`，选中与未选中文字同色，四组配色实测最差 `5.2:1`（见 `MAINTENANCE.md`） |
| niri 窗口边框与 focus-ring 不跟随 Noctalia 配色 | 不再依赖上游 `niri` 内置模板（它会写 DMS 独占的目录），本层复制其载荷为自定义模板 `niri-colors`，渲染到 `~/.config/niri-noctalia/noctalia.kdl` 并由本层配置可选 include |
| Noctalia 设置面板底部超出屏幕 | 该窗口是普通 toplevel 而非图层，固定请求 1080x920，超过本机 1365x768 的逻辑输出高度；窗口规则改为 `open-floating false` 加 `open-maximized true`，由布局收进工作区。不用 `open-maximized-to-edges`：它会设 xdg 的 Maximized 状态，圆角随之被清零 |
| 没有图形化的窗口规则编辑器 | Noctalia 不做（上游请求 #4268 关闭为 `NOT_PLANNED`），改用 NiriMod；包的 `nirimod` 命令注入 `--config` 指向可写的 `custom.kdl`，避免编辑器去写只读的 `config.kdl`（见 `MAINTENANCE.md`） |
| 深浅色不随时间切换、壁纸也不跟着换 | `theme.mode = "auto"` 加 `theme-auto.nix` 里的抚州坐标（离线解析日出日落）；壁纸图另由 `started` 与 `theme_mode_changed` 两个钩子按解析结果切换（Noctalia 自己只翻调色板，不重新应用壁纸） |
| 首次切到 noctalia 层时 Home Manager activation 失败 | ghostty 的 onFilesChange 校验钩子对尚未渲染的 `themes/noctalia` 返回非零，`set -e` 中止整个 activation，其后的 sd-switch 与 `custom.kdl` 播种都被跳过；改为由 `terminal.nix` 播种一个占位主题文件，并用 `entryBefore onFilesChange` 保证早于校验 |
| KDE Connect 指示器启动后没有托盘图标 | 它的 StatusNotifierItem 恒为 `Passive`（从不切换 Active），Noctalia 的 tray 默认 `hide_passive = true` 将其隐藏；层内声明 `widget.tray.hide_passive = false` |
| kdeconnectd 每次登录崩溃（could not connect to display） | 单元原来 `WantedBy = default.target`，早于图形会话环境启动，Qt 回退 xcb 插件失败，重启 5 次后 start-limit-hit；改为 `After`/`PartOf`/`WantedBy` 全部绑到 `graphical-session.target`，与 noctalia.service 同样拿到 `WAYLAND_DISPLAY` |
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
