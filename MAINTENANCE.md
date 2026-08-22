# 维护清单

记录仓库中依赖上游修复、外部补丁、临时绕过，或临时替代原始包来源的配置。更新 `flake.lock`、升级相关输入或调整覆盖前，应逐项重新评估；已满足移除条件时，删除覆盖并完成对应验证。

## 审查范围

- 检查 `flake.nix` 的所有输入、`nixpkgs.overlays`、`overrideAttrs`、`fetchpatch`、不安全包许可，以及被注释禁用的模块或服务。
- 任何 fork 只要用于替代原本由 Nixpkgs、其他 flake 或上游仓库提供的包，就必须在本文档记录；fork 可以属于任意个人或组织，并不限定为本人的仓库。
- 长期维护的独立配置或包源不因其所有者而自动列入；只有存在明确的上游回归、移除或重新启用条件时才需要记录。

## 上游包源替换

### `xwayland-satellite` fork 的弹出窗口锚点修复

- **位置：** `flake.nix` 的 `xwayland-satellite` 输入及对应覆盖。
- **影响：** 用 `Mooling0602/xwayland-satellite` 的 `6309aa1` 提供的包替代了原来 `niri` 输入中的 `xwayland-satellite-unstable`；该 fork 比当前 `niri` 锁定的上游提交多出一个补丁提交。
- **相关提交：** `a86d3ef`（`fix!: use personal xwayland-satellite patch`）。
- **补丁与上游：** https://github.com/Mooling0602/xwayland-satellite/commit/6309aa16e216189d5339857274e53030b7957a4d ，上游 PR： https://github.com/Supreeeme/xwayland-satellite/pull/448
- **移除条件：** PR #448 合并，且更新后的 `niri` 输入锁定的 `xwayland-satellite-unstable` 已包含该修复；仅 PR 合并不足以移除 fork。
- **复查方法：** 更新 `niri` 后，删除 fork 输入并恢复覆盖为：

  ```nix
  xwayland-satellite = inputs.niri.packages.${final.stdenv.hostPlatform.system}.xwayland-satellite-unstable;
  ```

  然后运行：

  ```fish
  nix flake update niri
  nix build .#nixosConfigurations.mooling-laptop.config.system.build.toplevel --no-link
  ```

  构建成功后，在受分数缩放影响的 XWayland 应用中验证弹出窗口不再出现零尺寸锚点。

## 临时构建绕过

### `dlib` 的 `build-cores.patch` 失配（Python 3.14 / dlib 20.0.1）

- **位置：** `flake.nix` 的 `pythonPackagesExtensions` 覆盖 + `patches/dlib-build-cores.patch`。
- **影响：** nixpkgs 输入更新后 dlib 升级到 20.0.1，`python3.14-dlib` 构建失败，连带依赖它的 `face-recognition`、`howdy`、`pam.d` 及整个 `nixos-system-*` 闭包全部失败。两处独立的 20.0.1 上游回归：
  1. `setup.py` 把 `num_available_cpu_cores()` 从 `class CMakeBuild` 内部移到模块顶层，nixpkgs 自带 `build-cores.patch`（按旧行号 `-170,23` 书写）在 `patchPhase` 报 `Hunk #1 FAILED`。
  2. `CMakeBuild` 不再把 `--set` 注册为 distutils 的 `user_options`，而 `get_extra_cmake_options()` 只在 `build_extension` 运行时（distutils 已解析完命令行之后）才手工清理 `sys.argv`；因此 nixpkgs 默认 `preConfigure` 通过 `--set` 传递 CMake flags 时会报 `error: option --set not recognized`。
- **当前处理：** 用 `./patches/dlib-build-cores.patch`（针对 dlib 20.0.1 新源码，函数体替换为 `return os.getenv("NIX_BUILD_CORES", 1)`，语义与上游一致）替换 `dlib` 的 `patches`；并覆盖 `preConfigure`，把 nixpkgs `cmakeFlags` 中本就以 `DLIB_` 开头的项（如 `-DDLIB_USE_CUDA:BOOL=FALSE`，先剥离 `:TYPE` 类型后缀，因环境变量名不能含 `:`）导出为同名环境变量（dlib 20.0.1 从 `DLIB_*` 环境变量读取选项并原样作为 CMake 变量名），不再生成 `--set`；`BUILD_SHARED_LIBS`、`USE_SSE/AVX` 等非 `DLIB_` 前缀项由 dlib 默认决定。
- **上游：** NixOS/nixpkgs issue https://github.com/NixOS/nixpkgs/issues/424045 ；dlib 源码 https://github.com/davisking/dlib
- **移除条件：** Nixpkgs 自带的 `build-cores.patch` 在 dlib 20.0.1（或更新）的 `setup.py` 上可干净应用，或上游已对补丁做出对应适配。
- **复查方法：** 更新 nixpkgs 后，临时移除该覆盖并运行：

  ```fish
  nix build .#nixosConfigurations.mooling-laptop.config.system.build.toplevel --no-link
  ```

  构建成功后删除覆盖（连同 `patches/dlib-build-cores.patch`），再重复同一命令确认。

### `click-threading` 的 Python 3.14 测试收集失败

- **位置：** `flake.nix` 的 `pythonPackagesExtensions` 覆盖。
- **影响：** `click-threading 0.5.0` 的 pytest 会将 `docs/conf.py` 作为 doctest 模块收集；该文件导入 Python 3.14 已移除的 `pkg_resources`，导致构建失败，并阻断依赖它的 `vdirsyncer`、`khal` 及 Home Manager 系统闭包。
- **当前处理：** 只将 `docs/conf.py` 加入 `disabledTestPaths`，其余测试与 `pythonImportsCheck` 仍会执行。
- **相关提交：** `30fa899`（`fix: disable pytest of module "docs/conf.py" for python package click-threading`）。
- **上游：** https://github.com/click-contrib/click-threading/ ，Nixpkgs 包定义： https://github.com/NixOS/nixpkgs/blob/nixos-unstable/pkgs/development/python-modules/click-threading/default.nix
- **移除条件：** Nixpkgs 为该包原生跳过该文档配置、上游移除 `pkg_resources` 依赖，或升级后的包在不使用本覆盖时可成功构建。
- **复查方法：** 临时移除此覆盖后运行：

  ```fish
  nix build .#nixosConfigurations.mooling-laptop.config.system.build.toplevel --no-link
  ```

  成功后删除覆盖，再重复同一命令确认。

## 已解除的临时构建绕过

### Niri 与 `libdisplay-info 0.4` 的版本不兼容

- **原处理：** 在 `modules/system/desktop.nix` 中将 `programs.niri.package` 的 `libdisplay-info` 参数覆盖为 `libdisplay-info_0_2`。
- **解除原因：** 更新后的 Niri 包定义已不再接收该参数，且会自行选择兼容的 `libdisplay-info` 依赖；继续覆盖会在配置评估阶段报出 `unexpected argument 'libdisplay-info'`。
- **相关提交：** `4d9906a`（添加覆盖）；本次提交（移除覆盖）。
- **上游：** https://github.com/NixOS/nixpkgs/issues/545976 ，修复 PR： https://github.com/NixOS/nixpkgs/pull/546004
- **验证：** `nix build .#nixosConfigurations.mooling-laptop.config.system.build.toplevel --no-link --print-build-logs` 已通过。

### `face-recognition-models` 的 Python 3.14 `pkg_resources` 兼容性

- **原处理：** 在 `flake.nix` 的 `pythonPackagesExtensions` 覆盖中，将 `pkg_resources.resource_filename` 替换为 `importlib.resources.files`。
- **解除原因：** 更新后的 Nixpkgs 包定义已原生应用相同修复；继续执行本地 `--replace-fail` 会因旧代码已不存在而在 `patchPhase` 失败。
- **移除提交：** 待提交。
- **验证：** 完整系统闭包构建成功，`sudo nixos-rebuild switch` 已通过。

### `pdal` 与 GDAL 3.13 的元数据 API 兼容性

- **原处理：** 在 `flake.nix` 中采用 PDAL 上游提交 `eb7220a` 的元数据 API 修复。
- **解除原因：** Nixpkgs 的 `pdal 2.10.2` 已包含等效修复，继续应用覆盖会因目标代码不存在而在 `patchPhase` 失败。
- **移除提交：** `7ff1f8e`（`fix: remove obsolete pdal patch`）。
- **验证：** PDAL 的 143 项测试及完整系统闭包构建通过，`mooling-laptop` 配置切换成功。

### 最小特性 GDAL 的 Zarr 分片缓存测试

- **原处理：** 在 `flake.nix` 中为 `gdal-minimal` 跳过不满足 `netCDF` 前置条件的 Zarr 测试。
- **解除原因：** 当前 Nixpkgs 的标准 `gdal-minimal 3.13.2` 已有官方二进制缓存；移除覆盖后系统 dry-run 直接获取该缓存，不再触发本地 GDAL/VTK 编译。
- **验证：** 移除覆盖后 dry-run 显示 `gdal-minimal`、VTK、OpenCV、PDAL 和 Howdy 均为缓存下载项。

### `vtk` 与 GDAL 3.13 的元数据 API 兼容性

- **原处理：** 在 `flake.nix` 中为 VTK 添加 GDAL 3.13 元数据类型的条件编译补丁。
- **解除原因：** 当前 Nixpkgs 的标准 `vtk 9.5.2` 已有官方二进制缓存；移除覆盖后系统 dry-run 不再计划本地 VTK 编译。
- **验证：** `cache.nixos.org` 对标准 VTK、GDAL、OpenCV、PDAL 和 Howdy 路径均返回 `200`，移除覆盖后的 dry-run 仅计划缓存获取。

## 外部功能补丁

### `qt6ct-kde` 的 KColorScheme 支持

- **位置：** `flake.nix` 的 `nixpkgs.overlays`，由 `modules/system/packages.nix` 和 `modules/home/theme.nix` 共同使用。
- **目的：** 为 `qt6ct` 加入 `kconfig`、`kcolorscheme`、`kiconthemes` 构建依赖，并应用 Arch AUR `qt6ct-kde` 的 shenanigans 补丁，使 Qt 配色方案能够使用 KDE 的 `KColorScheme` 支持。DMS 生成的 `DankMatugen.colors` 依赖该能力；覆盖必须位于全局，否则 Niri 实际加载的原生 Qt6ct 平台插件会回退为浅色。
- **相关提交：** `d4c18f6`（`fix: use qt6ct-kde patch instead of vanilla qt6ct`）。
- **补丁来源：** 固定为 AUR `qt6ct-kde` 提交 [`8c1003e`](https://aur.archlinux.org/cgit/aur.git/plain/qt6ct-shenanigans.patch?h=qt6ct-kde&id=8c1003e13b7e7545e717273e0716f095f195bd13)。原 URL 指向可变分支头，2026-08-18 上游更新补丁后触发固定输出哈希不匹配；更新后的补丁仍针对 `qt6ct 0.11`，保留 KColorScheme、KConfig 和 KIconThemes 集成。
- **移除条件：** Nixpkgs 的 `qt6ct` 包已原生包含等效补丁和 KDE 依赖，或上游 `qt6ct` 已正式提供等效功能；删除前需确认 DMS 浅色和深色主题切换后的 Qt 应用配色正确。
- **复查方法：** 更新输入后检查 Nixpkgs 包定义：

  ```fish
  nix edit nixpkgs#qt6Packages.qt6ct
  ```

  若功能已上游化，删除此 `overrideAttrs`，构建系统后在图形会话中切换 DMS 主题验证。

### `obs-studio` 的 NVENC/QSV 硬件编码修复

- **位置：** `flake.nix` 的 `nixpkgs.overlays`（`obs-studio` `overrideAttrs` 追加 `postFixup`）。
- **包管理方式：** OBS 本体与插件由 Home Manager 的 `programs.obs-studio` 模块管理（`modules/home/obs.nix`，按 [NixOS Wiki](https://wiki.nixos.org/wiki/OBS_Studio) 推荐结构）；模块未指定 `package`，经 `useGlobalPkgs` 自动拾取本 overlay 的产物，故此覆盖对模块安装的 OBS 同样生效。
- **影响：** OBS 31+ 用独立子进程 `bin/obs-nvenc-test` 探测 NVENC 能力，但 Nixpkgs 只对 `lib/*.so` 执行 `addDriverRunpath`，测试进程的 RUNPATH 不含 `/run/opengl-driver/lib`，无法 dlopen `libnvidia-encode.so.1`，日志报 `Test process failed: nvenc_lib`，UI 中 NVENC 编码器全部消失。同时 `obs-qsv11` 依赖的 oneVPL 分发器找不到 GPU 运行时（`libmfx-gen`），选 QuickSync 编码器时报 `Failed to initialize MFX (MFX_ERR_NOT_FOUND)`。
- **当前处理：**
  1. 对 `bin/.obs-nvenc-test-wrapped` 追加 `addDriverRunpath`，使 NVENC 探测进程能找到 NVIDIA 驱动编码库；
  2. 为 `bin/obs` 包装器设置 `ONEVPL_SEARCH_PATH=${vpl-gpu-rt}/lib`（Alder Lake iGPU 的 oneVPL 运行时，Gen12+），恢复 QuickSync。
- **上游：** NixOS/nixpkgs issue https://github.com/NixOS/nixpkgs/issues/382666 （NVENC 部分，OBS 31 起复现，仍未修复）。
- **移除条件：** Nixpkgs 的 `obs-studio` 对 `bin/obs-nvenc-test`（及任何新探测二进制）执行了 `addDriverRunpath` 或等效处理，且 oneVPL 运行时可被分发器自动发现（例如包内自带 `vpl-gpu-rt` 依赖）。
- **复查方法：** 更新 nixpkgs 后运行：

  ```fish
  obs-nvenc-test | head -3    # 应输出 nvenc_supported=true
  grep -o ONEVPL_SEARCH_PATH.* "$(command -v obs)"
  ```

  若前者成立且后者为空但 OBS 内 QuickSync 编码器可用，即可删除此覆盖并重建验证。

## 配置例外与兼容层

### Firebat T5K 的 tuxedo-drivers 兼容白名单

- **位置：** `flake.nix` 的 `linuxPackages_latest` 覆盖（内嵌补丁），以及 `hosts/mooling-laptop/default.nix` 的驱动配置。
- **影响：** Firebat T5K 与 Clevo 键盘协议兼容，但上游 `tuxedo-drivers` 的 DMI 安全门默认只接受 TUXEDO 机型；覆盖仅加入 `Firebat Computer` + `T5K Series` 的精确匹配。默认亮度行为保持由驱动/硬件决定，不声明式强制关闭。
- **上游：** https://gitlab.com/tuxedocomputers/development/packages/tuxedo-drivers
- **移除条件：** 上游兼容性表原生接受该 DMI 组合；移除前验证 `tuxedo_keyboard`、`clevo_acpi` 和 `/sys/class/leds/rgb:kbd_backlight` 在干净启动后可用。
- **复查方法：** 检查上游兼容性表是否已有该 DMI 条目，然后运行 `cat /sys/class/leds/rgb:kbd_backlight/{brightness,max_brightness}`。

### Firebat T5K 的 DMS 键盘 RGB 同步

- **位置：** `hosts/mooling-laptop/default.nix` 的 `dms-keyboard-backlight-sync` systemd service 与 path unit。
- **影响：** DMS 会在 `~/.local/share/color-schemes/DankMatugen.colors` 写入动态调色板。该服务监听该文件，读取 `Colors:Selection/BackgroundNormal` 并写入 `rgb:kbd_backlight/multi_intensity`；只更新 RGB，不改变键盘背光亮度，也不依赖 TUXEDO Control Center。
- **上游：** DMS：https://github.com/AvengeMedia/DankMaterialShell ，TUXEDO 键盘接口：https://gitlab.com/tuxedocomputers/development/packages/tuxedo-drivers
- **移除条件：** DMS 原生支持通过稳定接口控制键盘 RGB。
- **复查方法：** 重建后切换 DMS 配色，运行 `cat /sys/class/leds/rgb:kbd_backlight/multi_intensity`，确认数值等于 `kreadconfig6 --file ~/.local/share/color-schemes/DankMatugen.colors --group 'Colors:Selection' --key BackgroundNormal` 的逗号替换为空格后的结果；同时确认 `cat /sys/class/leds/rgb:kbd_backlight/brightness` 未变化。

### DMS 的可写 `adw-gtk3` 副本

- **位置：** `modules/home/theme.nix` 的 `home.activation.installDmsAdwGtk3`。
- **影响：** DMS 1.6 的 `scripts/gtk.sh` 只在 `~/.local/share/themes/`、`~/.themes/` 和 `/usr/share/themes/` 查找 `adw-gtk3`，并在 GTK3 的样式表中原地注入 Matugen 色表。Home Manager 安装的 `adw-gtk3` 位于只读 Nix store，因而 DMS 只能退回全局 CSS 覆盖；其 GTK3 补丁步骤以退出码 2 结束，随后不会调用将 `gtk-theme` 切换为 `adw-gtk3`/`adw-gtk3-dark` 的刷新逻辑，传统 GTK 应用会停留在浅色主题。
- **当前处理：** Home Manager 激活时仅在主题不存在时，将 Nix 包的两个变体复制到 `~/.local/share/themes/` 并授予用户写权限。之后目录完全由 DMS 管理；不使用 `home.file`，避免创建 DMS 无法修改的 store symlink。
- **上游：** [DMS GTK helper](https://github.com/AvengeMedia/DankMaterialShell/blob/master/quickshell/scripts/gtk.sh)，[DMS GTK 切换逻辑](https://github.com/AvengeMedia/DankMaterialShell/blob/master/quickshell/Common/Theme.qml)。
- **移除条件：** DMS 能通过 `XDG_DATA_DIRS` 使用 Nix store 中的主题，或停止原地修改 `adw-gtk3` 样式表。
- **复查方法：** 重建后切换一次 DMS 深浅色模式，确认 `dconf read /org/gnome/desktop/interface/gtk-theme` 分别返回 `'adw-gtk3-dark'` 和 `'adw-gtk3'`，并检查两个 `~/.local/share/themes/adw-gtk3*` 目录中的 CSS 末尾含有 `BEGIN DMS OVERRIDE`。

### Niri 下 `xdg-desktop-portal` 的深浅色状态同步

- **位置：** `modules/home/theme.nix` 的 `xdg.portal.config` 与 `xdg.dataFile`。
- **影响：** DMS 会通过 dconf 写入 `org.gnome.desktop.interface color-scheme`，但 `xdg-desktop-portal 1.22` 可同时加载 GTK、GNOME 和 KDE 的 `Settings` 后端，导致门户向 QQ、Telegram、Zen 等应用报告与 DMS 相反的深浅色状态。
- **当前处理：** 在通用和 Niri 门户配置中将 `org.freedesktop.impl.portal.Settings` 固定为 GTK；同时从用户优先级的 GNOME/KDE portal 定义中去除该接口，仅保留 GTK 作为 Settings 提供方。原定义直接由当前 Nix 包读取，避免手工复制后随上游接口列表漂移。
- **上游：** xdg-desktop-portal [#2033](https://github.com/flatpak/xdg-desktop-portal/issues/2033)，修复 PR [#2048](https://github.com/flatpak/xdg-desktop-portal/pull/2048)；相关 DMS/Niri 报告 [#2140](https://github.com/AvengeMedia/DankMaterialShell/issues/2140)。
- **移除条件：** 使用的 `xdg-desktop-portal` 已包含 #2048 的等效修复，且移除两个用户 portal 定义后，DMS 深色时门户仍返回 `uint32 1`、浅色时返回 `uint32 2`，并且应用能动态收到切换通知。
- **复查方法：** 临时移除两个 `xdg.dataFile` 条目后，重建并重启 `xdg-desktop-portal`；用下列命令分别在 DMS 的深色和浅色模式下检查：

  ```fish
  gdbus call --session --dest org.freedesktop.portal.Desktop --object-path /org/freedesktop/portal/desktop --method org.freedesktop.portal.Settings.Read org.freedesktop.appearance color-scheme
  ```

### Fcitx5 Plasma 候选窗的 DMS 深浅色同步

- **位置：** `modules/home/desktop.nix` 的 `fcitx5-dms-theme-sync` 用户 service 与 path unit。
- **影响：** Fcitx5 的实验性 `plasma` Classic UI 主题跟随 Plasma Shell 的 SVG 主题，而不读取 DMS 发布的门户深浅色或强调色；在 Niri 会话中它会回退到白色 `breeze-light` 和固定蓝色高亮。服务监听 DMS 写入的 `DankMatugen.colors`，根据同一文件的窗口背景亮度选择 `breeze-light` 或 `breeze-dark` 色表来组装私有主题；资源同时写入 Plasma 和 Fcitx 生成器的标准查找路径，并从该次色表读取选择前景/背景色来重着色候选项，最后调用 Fcitx `Controller1.Restart`。该接口与系统托盘的“重启”相同，会重新创建缓存 `NormalColor` 的 Classic UI，同时保留原实例的插件环境与输入法列表。这样不会因 DMS 先写色表、后更新 dconf 而将浅色调色板配上深色背景，也不必手动重启输入法。
- **范围：** 只使用已由 `fcitx5-configtool` 引入的 `libplasma`、`kconfig` 与 `kcolorscheme` 库，以及只用于重着色候选项 PNG 的 ImageMagick；不会安装或启动 Plasma Shell、KWin 或其他 KDE 桌面服务。同步 service 不直接由 `graphical-session.target` 启动，而仅由 path unit 在 DMS 写入色表后触发；DMS 本身必须在该 target 之后启动，若同时把同步 service 作为 target 成员并声明 `After=dms.service`，systemd 会形成排序循环并丢弃 DMS 的启动任务。
- **移除条件：** DMS 提供原生 Fcitx5 模板，或 Fcitx5 的 Plasma 主题能直接根据 `org.freedesktop.appearance color-scheme` 选择浅/深资源。
- **复查方法：** 暂停 path unit 后切换 DMS 深浅色，确认候选窗不再变化；恢复后运行 `systemctl --user start fcitx5-dms-theme-sync.service`，检查 `~/.local/share/fcitx5/themes/dms-plasma/panel.png` 的背景随模式切换。

### `pnpm-9.15.9` 的不安全包许可

- **位置：** `modules/system/packages.nix` 的 `permittedInsecurePackages`。
- **影响：** 全局允许 Nixpkgs 标记为不安全的 `pnpm-9.15.9`；当前系统闭包未包含该版本，故必须在依赖更新时确认许可是否仍被任何构建路径需要。
- **相关提交：** `dc870fa`（`fix: allow insecure package pnpm-9.15.9`）。
- **移除条件：** 依赖已升级到受支持的 pnpm，或移除许可后系统可正常构建。
- **复查方法：** 临时删除该条目后运行：

  ```fish
  nix build .#nixosConfigurations.mooling-laptop.config.system.build.toplevel --no-link
  ```

  若失败，记录仍依赖该版本的包；若成功，永久删除该许可。

### Wine 的 PipeWire 与 WoW64 兼容层

- **位置：** `modules/system/packages.nix` 的 `pulseaudio`、`wine64-symlink` 与 `WINEDLLOVERRIDES`，以及 `modules/home/default.nix` 和生成的 Fish 配置中的同一变量。
- **影响：** 禁用 `winealsa.drv`，改由 PipeWire 的 PulseAudio 兼容层处理音频，以避免 `winecfg` 枚举音频设备时卡死；同时伪造 `wine64`，满足 WoW64 模式下的 `winetricks` 查找。
- **相关提交：** `89f35ae`（`fix: add pulseaudio and disable winealsa to prevent winecfg audio tab freeze`）；`6201ec7`（`fix: add wine64 symlink for winetricks WoW64 compatibility`）。
- **移除条件：** 当前 Wine 在 PipeWire 下运行 `winecfg` 不再卡死，且 WoW64 的 `winetricks` 可直接找到实际的 `wine64` 可执行文件。
- **复查方法：** 在测试环境中移除上述覆盖，运行 `winecfg` 并执行实际使用的 WoW64 `winetricks` 流程；两者通过后再删除兼容层。

### Apollo 串流模块被临时禁用

- **位置：** `hosts/mooling-laptop/default.nix` 中被注释的 `./streaming.nix` 导入。
- **影响：** `services.apollo` 的串流、UPnP 和防火墙配置目前均未启用。
- **相关提交：** `52cbddf`（`fix!: disable streaming(service.apollo) due to upstream error`）；当时未记录可追踪的上游问题。
- **移除条件：** 已定位并确认原上游错误不再复现，或上游 Apollo/`apollo-flake` 已修复相关问题。
- **复查方法：** 恢复导入后运行系统构建；确认通过后切换配置，并验证 `apollo` 服务状态、串流连接、UPnP 与虚拟显示器行为。

### Home Manager 冲突备份后缀

- **位置：** `flake.nix` 的 `home-manager.backupFileExtension = "backup"`。
- **影响：** 激活时会将与 Home Manager 目标文件冲突的既有文件重命名为 `.backup`；原用于处理由 DMS/Niri 运行时管理的 `config.kdl` 冲突。
- **相关提交：** `64177f6`（`fix: add home-manager.backupFileExtension to resolve config.kdl conflicts`）；`a383c84`（`fix!: stop declaratively managing DMS and NvChad runtime config`）移除了最初的配置冲突来源。运行时 Niri/DMS 配置已不再由 Home Manager 声明式管理，因此需重新确认该后缀是否仍有必要。
- **移除条件：** 不存在其他需要保留的 Home Manager 目标文件冲突，且移除该选项后的 Home Manager 激活成功。
- **复查方法：** 临时移除该选项后执行常规 `nixos-rebuild switch`；若激活报出文件冲突，先确认该目标文件是否应由 Home Manager 接管，再决定是否保留该后缀。
