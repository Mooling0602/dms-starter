# 维护清单

记录仓库中依赖上游修复、外部补丁、临时绕过，或临时替代原始包来源的配置。更新 `flake.lock`、升级相关输入或调整覆盖前，应逐项重新评估；已满足移除条件时，删除覆盖并完成对应验证。

## 审查范围

- 检查 `flake.nix` 的所有输入、`overlays/` 下的全部覆盖（`overrideAttrs`、`fetchpatch`）、不安全包许可，以及被注释禁用的模块或服务。
- 任何 fork 只要用于替代原本由 Nixpkgs、其他 flake 或上游仓库提供的包，就必须在本文档记录；fork 可以属于任意个人或组织，并不限定为本人的仓库。
- 长期维护的独立配置或包源不因其所有者而自动列入；只有存在明确的上游回归、移除或重新启用条件时才需要记录。

## 上游包源替换

### `niri-input-portal` 提供 niri 缺失的 InputCapture 门户后端

- **位置：** `overlays/custom-packages.nix` 的 `nix-packages` 条目；`modules/desktop/dms-with-niri/xdg-portals.nix` 与 `modules/desktop/noctalia-with-niri/xdg-portals.nix` 的 `xdg.portal.extraPortals`、`xdg.portal.config` 与 `systemd.user.services`（两个桌面层各留一份同内容配置，因为门户跟随桌面层加载）；`~/.config/niri/config.kdl` 的 `Mod+Shift+Space` 逃生键（该文件由运行时管理，不由 Nix 声明）。包本体与本地补丁 `fix-eis-device-region.patch` 位于 `Mooling0602/nix-packages` 的 `pkgs/by-name/ni/niri-input-portal/`。
- **影响：** niri 未实现 `org.freedesktop.impl.portal.InputCapture`，而 `xdg-desktop-portal-gnome` 只在 niri 提供 `org.gnome.Mutter.InputCapture` 时才发布该接口，因此 Deskflow、Synergy 3、Input Leap 等在 niri 下作为 server 共享键鼠时会以 `failed to initialize input capture session` 失败。nixpkgs 未收录该后端，故自行打包并跟踪上游 `main`（上游无 tag 与 release）。
- **当前处理：** 包经 `nix-packages` 输入进入 `pkgs`；门户路由在 `common` 与 `niri` 两个 section 中把 `InputCapture` 与 `Clipboard` 指向 `niri-input`；`Clipboard` 必须一并路由，否则剪贴板门户会挂到未创建该会话的后端上，客户端随后陷入 create/destroy 死循环。D-Bus 激活单元在 Home Manager 中显式声明，以去掉上游的 `ConditionEnvironment=WAYLAND_DISPLAY`（条件不成立时 systemd 会静默跳过该单元，D-Bus 只报服务名不可激活）。niri 侧的 `Mod+Shift+Space allow-inhibiting=false` 绑定调用 `niri-input-portal --release`：捕获期间指针被锁、键盘被独占，而 niri 会先于客户端处理自己的绑定，因此这是唯一可靠的逃生出口；`dms setup` 重新生成 `config.kdl` 后需要重新添加该绑定。
- **本地补丁：** `fix-eis-device-region.patch` 让后端下发 `ei_device.region`。上游从不下发，而这是 libei 客户端唯一能确定"本机屏幕"尺寸的信息：缺失时 Deskflow 保持 1×1 的屏幕模型，每次捕获激活的光标位置都被压到 `(0, 0)`，该点先满足上边缘判定，于是下边缘与右边缘成为死代码：客户端配在本机下方或右侧时指针切不过去，配在上方反而能用。补丁在 `ConnectToEIS` 时取一次输出布局并集，在创建每个 device 的回调里、`ei_device.done` 之前下发；顺序是硬要求，libei 只在构建 device 时读取 region，协议中没有 region 事件，晚发等同于没发。
- **上游：** [Qingswe/niri-input-portal](https://github.com/Qingswe/niri-input-portal)；缺口跟踪：niri [#823](https://github.com/YaLTeR/niri/issues/823)（自 2024-11 起 open）、[#1966](https://github.com/YaLTeR/niri/pull/1966)（未合并）。region 必须在 `ei_device.done` 之前下发的旁证是 mutter 的 `483601844b4c72fc34b1818a59fef7879cdb5238`（"backends/eis-client: Do not add device before adding EIS regions"）。
- **移除条件：** 分两层。补丁层：上游自行下发 `ei_device.region` 后即可删掉 `fix-eis-device-region.patch` 与 `package.nix` 中的 `patches` 一行，包本身继续保留。整包层：niri 自行实现 InputCapture 门户（#823 关闭，或 #1966 及后续工作合并），或该后端被 nixpkgs 收录；此时再移除 overlay 条目、`extraPortals` 中的包、两条门户路由与 systemd 单元。
- **复查方法：** 重建并重启 `xdg-desktop-portal` 后读取门户能力值，接入后应为 `u 3`（keyboard | pointer），未接入时为 `u 0`：

  ```fish
  busctl --user get-property org.freedesktop.portal.Desktop /org/freedesktop/portal/desktop org.freedesktop.portal.InputCapture SupportedCapabilities
  ```

  补丁是否仍然必要，直接看上游有没有自己调用 `.region(` 即可，无需构建：

  ```fish
  curl -s https://raw.githubusercontent.com/Qingswe/niri-input-portal/main/src/eis_server.rs | grep -n '\.region('
  ```

  补丁生效的现场证据：以 `NIRI_INPUT_PORTAL_LOG=debug` 启动后端，客户端连接时应出现 `reported device region <宽>x<高>`（pointer 与 keyboard 各一条），客户端侧 Deskflow 日志则由 `logical output size: unchanged (no region-reporting device present)` 变为 `logical output size: <宽>x<高>@0.0`，`active sides` 由 `T (0x08)` 变为 `B (0x10)`。

## 临时构建绕过

### VTK 9.5 的 pegtl 模块改名门控写反

- **位置：** `overlays/vtk-pegtl-gate.nix` 的 `vtk_9_5` 覆盖（`postPatch`）。
- **影响：** nixpkgs 输入更新到 `nixos-26.11pre1089111.6510408d147d` 后，整个 `nixos-system-*` 闭包无法构建。该 rev 含上游提交 `a1a2b117f5`（PR #571724），它把 `VTK::pegtl` 模块改名为 `VTK::vtkpegtl`（避开 openusd ≥ 26.05 经 `VTK::IOUSD` 导出的同名 CMake target），但 `pkgs/development/libraries/vtk/generic.nix` 中两处门控方向不一致：`postPatch` 用 `lib.versionOlder version "9.6"` 触发改名，而 `VTK_MODULE_USE_EXTERNAL_VTK_${if lib.versionAtLeast version "9.6" then "vtkpegtl" else "pegtl"}` 仍按旧名拼 flag。在 `vtk 9.5.2` 上模块被改名为 `VTK::vtkpegtl`，外部依赖开关却仍是 `VTK_MODULE_USE_EXTERNAL_VTK_pegtl=FALSE`，导致改名后的模块匹配不上该 flag、转而查找系统 PEGTL，而派生中根本没有 pegtl 路径，configure 以 `Could not find the PEGTL external dependency` 失败。
- **传播路径：** `vtk` → `opencv-4.13.0`（经 `opencv4Full`）→ `python3.14-face-recognition` → `howdy` → `system-path`、`pam.d`、`etc`、`activate`、`system-units` 等 23 个派生连锁失败。
- **当前处理：** 覆盖 `vtk_9_5`，把 `postPatch` 的门控改为 `prev.lib.versionAtLeast oldAttrs.version "9.6"`，与 `generic.nix` 中 flag 所在分支一致（9.5.x 不做改名）。只改 `vtk_9_5` 即可：`all-packages.nix` 中 `vtk` 是 `vtk_9_5` 的别名，下游 `opencv` 经 `opencv4Full` 同样取自该属性，实测覆盖后 `vtk` 与 `opencv` 的派生同步变化。修补后 VTK 输出为 `/nix/store/xb92f3v6a3f92xcxv6vba3i6mbnqnbmm-vtk-9.5.2`，在 `cache.nixos.org` 返回 `200`，因此不会触发本地 VTK 编译。
- **上游：** 修复为 NixOS/nixpkgs 提交 [`00718d4899`](https://github.com/NixOS/nixpkgs/commit/00718d4899)（"vtk: apply the pegtl module rename to 9.6, not 9.5"，PR [#572295](https://github.com/NixOS/nixpkgs/pull/572295)，2026-10-10 合并），仅改 `versionOlder` 为 `versionAtLeast`。引入缺陷的提交为 [`a1a2b117f5`](https://github.com/NixOS/nixpkgs/commit/a1a2b117f5)（PR [#571724](https://github.com/NixOS/nixpkgs/pull/571724)）。
- **移除条件：** `flake.lock` 中的 `nixpkgs` 前进到包含 `00718d4899` 的 rev。该输入为 `tarball` 类型，锁定在 `nixpkgs_2` 节点（`flake.lock` 内另有 github 类型的 `nixpkgs` 与 `nixpkgs-stable` 节点，均非本仓库使用）；`channels.nixos.org/nixos-unstable/git-revision` 目前仍指向 `6510408d147d`，故 `nix flake update` 在 channel 推进前无效。
- **复查方法：** 直接检查当前配置所用 nixpkgs 中的门控方向：

  ```fish
  set nixpkgs (nix eval --raw --impure --expr '(builtins.getFlake (toString ./.)).nixosConfigurations.mooling-laptop.pkgs.path')
  grep -n 'postPatch = lib.optionalString' $nixpkgs/pkgs/development/libraries/vtk/generic.nix
  ```

  输出含 `versionOlder version "9.6"` 表示修复尚未到位，含 `versionAtLeast version "9.6"` 则可移除。确认后删除 `overlays/vtk-pegtl-gate.nix` 与 `overlays/default.nix` 中的对应条目，再运行：

  ```fish
  nix build .#nixosConfigurations.mooling-laptop.config.system.build.toplevel --no-link
  ```

  构建成功即完成移除。

### `dlib` 的 `build-cores.patch` 失配（Python 3.14 / dlib 20.0.1）

- **位置：** `overlays/python-fixes.nix` 的 `pythonPackagesExtensions` 覆盖 + `patches/dlib-build-cores.patch`。
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

- **位置：** `overlays/python-fixes.nix` 的 `pythonPackagesExtensions` 覆盖。
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

### `ltrace` 的 `demangle` 测试在 GCC 16 下编译失败

- **位置：** `modules/home/defaults/packages.nix` 的 `ltrace` 覆盖。
- **影响：** nixpkgs 输入更新到 `nixos-26.11pre1082427.b4fd65b198c5` 后，工具链默认编译器升到 GCC 16.2.0。`testsuite/ltrace.minor/demangle-lib.cpp` 里的 `volatile int Fv_Vi(void)` 触发 GCC 16 新增的 `-Wvolatile` 警告，而 ltrace 的测试框架（`testsuite/lib/ltrace.exp` 中 `if { $result != "" ... }`）只判断编译器输出是否为空：任何输出（含 warning）都算 "compile failed"。测试程序因此未生成，`make check` 报 15 个 unexpected failures 并以退出码 2 结束。
- **附带影响：** 上游 Hydra 构建同一派生（`049gzs92…` → 输出 `0l6dxxqz…-ltrace-0.7.91`）同样失败（[build 347357345](https://hydra.nixos.org/build/347357345)，`buildstatus` 为 failed），该输出因此没有任何二进制缓存；本机重建时必然回落为本地构建并复现同一失败。
- **当前处理：** 按上游 MR !112 的思路，在 `postPatch` 中删除 `demangle-lib.cpp` 与 `demangle.cpp` 里 `Fv_Vi` 的 `volatile` 限定符（该限定符不参与 Itanium 符号名，不影响测试校验的 `Fv_Vi()` 名称）。测试套件得以保留并全部通过：244 expected passes / 0 unexpected failures。
- **上游：** ltrace MR https://gitlab.com/cespedes/ltrace/-/merge_requests/112 （2026-09-30 提交，尚未合并）；nixpkgs 的 ltrace 定义尚未收录该修复：https://github.com/NixOS/nixpkgs/blob/nixos-unstable/pkgs/by-name/lt/ltrace/package.nix
- **移除条件：** ltrace 上游合并该修复且 nixpkgs 收录（或 nixpkgs 改用 ltrace 0.8.1 等其他方式修复），使默认 `doCheck = true` 下构建可通过。
- **复查方法：** 删除该覆盖后运行：

  ```fish
  nix build .#nixosConfigurations.mooling-laptop.pkgs.ltrace --no-link
  ```

  构建成功（或该输出已能从二进制缓存取得）即可移除本覆盖。

## 已解除的临时构建绕过

### `face-recognition-models` 的 Python 3.14 `pkg_resources` 兼容性

- **原处理：** 在 `flake.nix` 的 `pythonPackagesExtensions` 覆盖中，将 `pkg_resources.resource_filename` 替换为 `importlib.resources.files`。
- **解除原因：** 更新后的 Nixpkgs 包定义已原生应用相同修复；继续执行本地 `--replace-fail` 会因旧代码已不存在而在 `patchPhase` 失败。
- **移除提交：** `69d1b85`（`fix: remove obsolete face-recognition-models pkg_resources override`）。
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

- **位置：** `overlays/qt6ct-kde.nix`，由 `modules/home/defaults/theme.nix`（安装 qt6ct 本体）、`modules/desktop/dms-with-niri/ui.nix`（`platformTheme.name` 与 `QT_QPA_PLATFORMTHEME_QT6`）和 `modules/optional/wine.nix`（`QT_PLUGIN_PATH`）共同使用。
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

- **位置：** `overlays/obs-nvenc-qsv.nix`（`obs-studio` `overrideAttrs` 追加 `postFixup`）。
- **包管理方式：** OBS 本体与插件由 Home Manager 的 `programs.obs-studio` 模块管理（`modules/optional/obs.nix`，按 [NixOS Wiki](https://wiki.nixos.org/wiki/OBS_Studio) 推荐结构）；模块未指定 `package`，经 `useGlobalPkgs` 自动拾取本 overlay 的产物，故此覆盖对模块安装的 OBS 同样生效。
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

### Chrome 在 KDE 下改用 libsecret 密钥后端

- **位置：** `modules/home/mooling/packages.nix` 的 `google-chrome.override { commandLineArgs = "--password-store=gnome-libsecret"; }`。
- **影响：** Chrome/Chromium 在 Linux 上**按桌面环境自动挑选加密后端**。`FreedesktopSecretKeyProvider::GetKey()` 用 `--password-store` 的值分支，未给定时才调 `base::nix::GetDesktopEnvironment()`：`KDE`（配合 `KDE_SESSION_VERSION=6`）走 `org.kde.kwalletd6` 的 `Chrome Keys/Chrome Safe Storage`，而 niri 不匹配任何枚举、落进 `DESKTOP_ENVIRONMENT_OTHER`，走 `org.freedesktop.secrets`（gnome-keyring）的 `Chrome Safe Storage`（`freedesktop_secret_key_provider.cc:206-247`、`base/nix/xdg_util.cc:94-149`）。

  两个后端**各自独立随机生成 16 字节密钥**（读不到就在各自的库里新造一把），但派生算法与数据前缀完全相同（PBKDF2-HMAC-SHA1 迭代 1 次、salt `saltysalt`、AES-128-CBC、tag `v11`）。于是「换桌面」不会覆写数据，只是同一份 profile 去读另一把钥匙：令牌解不开（`token_service_table.cc` 报 `Failed to decrypt token for service AccountId-…`），Chrome 要求重新登录；切回原桌面又能解开，因为失败路径只返回 `std::nullopt`、不写回。本机实测 47 个 cookie 由 KWallet 那把解开、340 条 `Login Data` 与 `AccountId-…` 令牌由 gnome-keyring 那把解开，两把互不可解。

  钉死 `gnome-libsecret` 后两个桌面共用同一把钥匙。前提在该仓库已具备：`modules/system/keyring.nix` 在所有桌面层下都 `services.gnome.gnome-keyring.enable = true`，并把 `org.freedesktop.impl.portal.Secret` 指向 gnome-keyring。
- **为何不用其他值：** `basic` 会让 `v11` 数据（含全部已存密码）**永久不可解**，不可用；`kwallet6` 反向固定也可行，但那样 niri 一侧必须自行保证 KWallet 可达。另外 `gnome` / `gnome-keyring` 这两个值**当前代码已不再识别**（会打印 `Unknown password store:` 后回退自动探测），必须写 `gnome-libsecret`。
- **上游：** Chromium 按设计如此，非缺陷：[`docs/linux/password_storage.md`](https://chromium.googlesource.com/chromium/src/+/main/docs/linux/password_storage.md)（"Chromium chooses which store to use automatically, based on your desktop environment."）；下游同类报告 [brave#12088](https://github.com/brave/brave-browser/issues/12088)（`wontfix`）、[KDE bug 489493](https://bugs.kde.org/show_bug.cgi?id=489493)（与本文症状一致）。上游正在推进 portal 后端（`kDbusSecretPortal` 已默认开启）以取代这两个后端，但 `kSecretPortalKeyProviderUseForEncryption` 至今仍默认关闭，portal 密钥只用于解密、不参与加密，**因此不能靠它绕过本问题**。
- **移除条件：** 上游让 Chromium 在 Linux 上不再按桌面环境切换后端（例如 portal 后端全面接管并统一密钥来源），或 nixpkgs 的原生 `google-chrome` 包装已自带等效的固定参数。
- **复查方法：** 在 KDE 会话下确认 Chrome 实际走的是 libsecret。临时 profile 复现（不改动真实 profile）：

  ```fish
  # 应输出 tokens=1 / fails=0；去掉 --password-store 则退化为 tokens=0 / fails=1
  env -u DESKTOP_SESSION -u KDE_FULL_SESSION -u KDE_SESSION_VERSION XDG_CURRENT_DESKTOP=KDE \
    google-chrome --user-data-dir=/tmp/probe --no-first-run \
    --enable-logging=stderr --v=1 --headless=new about:blank 2>&1 \
    | grep -E 'number of tokens loaded|Failed to decrypt token'
  ```

  注意 `GetDesktopEnvironment()` 会读 `DESKTOP_SESSION`、`KDE_FULL_SESSION`、`KDE_SESSION_VERSION` 与 `GNOME_DESKTOP_SESSION_ID`，只改 `XDG_CURRENT_DESKTOP` 复现不出 KDE 分支，必须像上面那样先清掉它们。确认包装器已注入参数：

  ```fish
  grep -o -- '--password-store=[a-z0-9-]*' (readlink -f (command -v google-chrome))
  ```

### qtkeychain 在 KDE 下改用 libsecret 密钥后端

- **位置：** `modules/home/defaults/ssh.nix` 的 `systemd.user.sessionVariables.QTKEYCHAIN_BACKEND = "libsecret"`。
- **影响：** `ksshaskpass` 通过 qtkeychain 存取口令，而 qtkeychain 的 `detectDesktopEnvironment()` / `getKeyringBackend()`（`keychain_unix.cpp`，源码注释写明 "the following detection algorithm is derived from chromium, licensed under BSD, see base/nix/xdg_util.cc"）与 Chromium 是**同一套探测逻辑**：`XDG_CURRENT_DESKTOP=KDE` 且 `KDE_SESSION_VERSION=6` 时优先选 `org.kde.kwalletd6`，其余情况（niri 不匹配任何枚举、落进 `DesktopEnv_Other`）在 `LibSecretKeyring::isAvailable()` 通过后选 libsecret。该探测结果缓存在静态变量里、只求值一次，因此会话级设置即可全面生效。

  `ksshaskpass` 写入的条目用 `org.qt.keychain` schema，属性为 `server=ksshaskpass`、`user=<私钥路径>`、`type=plaintext`，实际存放在 `~/.local/share/keyrings/login.keyring`。切到 KDE 后 qtkeychain 转去 KWallet 的同名文件夹查找，那里没有该条目，于是每次都退回弹框，SSH key 自动解锁失效。钉死 libsecret 后两个桌面共用 gnome-keyring 里的同一份口令；前提由 `modules/system/keyring.nix` 提供（所有桌面层都启用 gnome-keyring，并由 PAM 解锁 login keyring）。
- **为何不用其他值：** `QTKEYCHAIN_BACKEND` 仅识别 `libsecret` / `gnome` / `kwallet4` / `kwallet5` / `kwallet6`；反向钉死 `kwallet6` 也可行，但那样 niri 一侧必须自行保证 KWallet 可达（niri 下并未启动 KWallet）。不设置该变量就只能去改桌面探测结果，不可行。注意这是**会话级**设置，同样影响其他链接 qtkeychain 的程序（kate / plasma-nm / kmailtransport / kdepim-runtime / krdp / kldap / ktextaddons）：落地时 KWallet 内只有 Chrome 的两条记录（且 Chrome 已改走 libsecret），无实际迁移成本。
- **上游：** qtkeychain 按设计跟随桌面环境，非缺陷：[`qtkeychain/keychain_unix.cpp`](https://github.com/frankosterfeld/qtkeychain/blob/master/qtkeychain/keychain_unix.cpp)。nixpkgs 的 `qtkeychain` 构建时固定链接 libsecret、且没有 KWallet 开关，包级无法指定后端。
- **移除条件：** qtkeychain 不再按桌面环境自动选择后端，或 nixpkgs 提供构建期指定后端的开关。
- **复查方法：** 在 KDE 会话下应能直接解锁（无弹框）：

  ```fish
  # 应输出 QTKEYCHAIN_BACKEND=libsecret，且下面一条命令无需输入口令即 keys=1
  systemctl --user show-environment | grep QTKEYCHAIN_BACKEND
  ssh-add ~/.ssh/key-mooling-laptop; and ssh-add -l | grep -c SHA256:
  ```

  反向对照：临时用 `env QTKEYCHAIN_BACKEND=kwallet6 ssh-add ~/.ssh/key-mooling-laptop` 应超时且 `keys=0`。

### Firebat T5K 的 tuxedo-drivers 兼容白名单

- **位置：** `overlays/tuxedo-firebat.nix` 的 `linuxPackages_latest` 覆盖（内嵌补丁），以及 `hosts/mooling-laptop/default.nix` 的驱动配置。
- **影响：** Firebat T5K 与 Clevo 键盘协议兼容，但上游 `tuxedo-drivers` 的 DMI 安全门默认只接受 TUXEDO 机型；覆盖仅加入 `Firebat Computer` + `T5K Series` 的精确匹配。默认亮度行为保持由驱动/硬件决定，不声明式强制关闭。
- **上游：** https://gitlab.com/tuxedocomputers/development/packages/tuxedo-drivers
- **移除条件：** 上游兼容性表原生接受该 DMI 组合；移除前验证 `tuxedo_keyboard`、`clevo_acpi` 和 `/sys/class/leds/rgb:kbd_backlight` 在干净启动后可用。
- **复查方法：** 检查上游兼容性表是否已有该 DMI 条目，然后运行 `cat /sys/class/leds/rgb:kbd_backlight/{brightness,max_brightness}`。

### Firebat T5K 的 DMS 键盘 RGB 同步

- **位置：** `hosts/mooling-laptop/desktop/dms-with-niri/keyboard-backlight-sync.nix` 的 `dms-keyboard-backlight-sync` systemd service 与 path unit。
- **影响：** DMS 会在 `~/.local/share/color-schemes/DankMatugen.colors` 写入动态调色板。该服务监听该文件，读取 `Colors:Selection/BackgroundNormal` 并写入 `rgb:kbd_backlight/multi_intensity`；只更新 RGB，不改变键盘背光亮度，也不依赖 TUXEDO Control Center。
- **上游：** DMS：https://github.com/AvengeMedia/DankMaterialShell ，TUXEDO 键盘接口：https://gitlab.com/tuxedocomputers/development/packages/tuxedo-drivers
- **移除条件：** DMS 原生支持通过稳定接口控制键盘 RGB。
- **复查方法：** 重建后切换 DMS 配色，运行 `cat /sys/class/leds/rgb:kbd_backlight/multi_intensity`，确认数值等于 `kreadconfig6 --file ~/.local/share/color-schemes/DankMatugen.colors --group 'Colors:Selection' --key BackgroundNormal` 的逗号替换为空格后的结果；同时确认 `cat /sys/class/leds/rgb:kbd_backlight/brightness` 未变化。

### DMS 的可写 `adw-gtk3` 副本

- **位置：** `modules/desktop/dms-with-niri/ui.nix` 的 `home.activation.installDmsAdwGtk3`。
- **影响：** DMS 的 `scripts/gtk.sh` 只在用户可写目录（`~/.local/share/themes/`、`~/.themes/`，以及 `system_theme_roots` 返回的其他用户目录）中查找 `adw-gtk3`，并在 GTK3 的样式表中原地注入 Matugen 色表（`is_user_theme_dir()` 显式排除只读路径，注释说明以 `^/usr` 判定会把 Nix store 路径误判为用户副本）。Home Manager 安装的 `adw-gtk3` 位于只读 Nix store，因而 DMS 无法就地修补；其 GTK3 补丁步骤以退出码 2 结束，随后不会调用将 `gtk-theme` 切换为 `adw-gtk3`/`adw-gtk3-dark` 的刷新逻辑，传统 GTK 应用会停留在浅色主题。
- **当前处理：** Home Manager 激活时仅在主题不存在时，将 Nix 包的两个变体复制到 `~/.local/share/themes/` 并授予用户写权限。之后目录完全由 DMS 管理；不使用 `home.file`，避免创建 DMS 无法修改的 store symlink。
- **上游：** [DMS GTK helper](https://github.com/AvengeMedia/DankMaterialShell/blob/master/quickshell/scripts/gtk.sh)，[DMS GTK 切换逻辑](https://github.com/AvengeMedia/DankMaterialShell/blob/master/quickshell/Common/Theme.qml)。
- **移除条件：** DMS 能通过 `XDG_DATA_DIRS` 使用 Nix store 中的主题，或停止原地修改 `adw-gtk3` 样式表。
- **复查方法：** 重建后切换一次 DMS 深浅色模式，确认 `dconf read /org/gnome/desktop/interface/gtk-theme` 分别返回 `'adw-gtk3-dark'` 和 `'adw-gtk3'`，并检查两个 `~/.local/share/themes/adw-gtk3*` 目录中的 CSS 末尾含有 `BEGIN DMS OVERRIDE`。

### Niri 下 `xdg-desktop-portal` 的深浅色状态同步

- **位置：** `modules/desktop/dms-with-niri/xdg-portals.nix` 与 `modules/desktop/noctalia-with-niri/xdg-portals.nix` 的 `xdg.portal.config` 与 `xdg.dataFile`。
- **影响：** 桌面 shell 会通过 dconf 写入 `org.gnome.desktop.interface color-scheme`（DMS 自己写入，Noctalia 则由其 gtk3/gtk4 模板的 `apply.sh` 同步），但 `xdg-desktop-portal 1.22` 可同时加载 GTK、GNOME 和 KDE 的 `Settings` 后端，导致门户向 QQ、Telegram、Zen 等应用报告与桌面相反的深浅色状态。
- **当前处理：** 在通用和 Niri 门户配置中将 `org.freedesktop.impl.portal.Settings` 固定为 GTK；同时从用户优先级的 GNOME/KDE portal 定义中去除该接口，仅保留 GTK 作为 Settings 提供方。原定义直接由当前 Nix 包读取，避免手工复制后随上游接口列表漂移。
- **上游：** xdg-desktop-portal [#2033](https://github.com/flatpak/xdg-desktop-portal/issues/2033)，修复 PR [#2048](https://github.com/flatpak/xdg-desktop-portal/pull/2048)；相关 DMS/Niri 报告 [#2140](https://github.com/AvengeMedia/DankMaterialShell/issues/2140)。
- **移除条件：** 使用的 `xdg-desktop-portal` 已包含 #2048 的等效修复，且移除两个用户 portal 定义后，DMS 深色时门户仍返回 `uint32 1`、浅色时返回 `uint32 2`，并且应用能动态收到切换通知。
- **复查方法：** 临时移除两个 `xdg.dataFile` 条目后，重建并重启 `xdg-desktop-portal`；用下列命令分别在 DMS 的深色和浅色模式下检查：

  ```fish
  gdbus call --session --dest org.freedesktop.portal.Desktop --object-path /org/freedesktop/portal/desktop --method org.freedesktop.portal.Settings.Read org.freedesktop.appearance color-scheme
  ```

### Fcitx5 Plasma 候选窗跟随桌面配色的同步（DMS 与 Noctalia）

- **位置：** `modules/desktop/dms-with-niri/fcitx-theme-sync.nix`（`fcitx5-dms-theme-sync`）与 `modules/desktop/noctalia-with-niri/fcitx-theme-sync.nix`（`fcitx5-noctalia-theme-sync`）的用户 service 与 path unit，各随所属桌面层加载。
- **影响：** Fcitx5 的实验性 `plasma` Classic UI 主题跟随 Plasma Shell 的 SVG 主题，而不读取桌面 shell 发布的门户深浅色或强调色；在 Niri 会话中它会回退到白色 `breeze-light` 和固定蓝色高亮。同步脚本监听本层 shell 写出的色表（DMS 是 `~/.local/share/color-schemes/DankMatugen.colors`，Noctalia 是它自己的 `kcolorscheme` 模板输出 `noctalia.colors`），根据同一文件的窗口背景亮度选择 `breeze-light` 或 `breeze-dark` 色表来组装私有主题；资源同时写入 Plasma 和 Fcitx 生成器的标准查找路径，并从该次色表读取选择前景/背景色来重着色候选项，最后调用 Fcitx `Controller1.Restart`。该接口与系统托盘的“重启”相同，会重新创建缓存 `NormalColor` 的 Classic UI，同时保留原实例的插件环境与输入法列表。这样不会因 shell 先写色表、后更新 dconf 而将浅色调色板配上深色背景，也不必手动重启输入法。两层生成的 Fcitx 主题目录都叫 `dms-plasma`：`~/.config/fcitx5/conf/classicui.conf` 是 Fcitx 自己写的运行时文件，其中 `Theme`/`DarkTheme` 已固定为这个名字，沿用它可以避免每次切换桌面都手改该文件；Noctalia 层只把内部使用的私有 Plasma SVG 主题命名为 `noctalia-fcitx-<mode>`。
- **上游没有 Fcitx5 模板：** Noctalia 5.2.1 的内置模板清单（`share/noctalia/assets/templates/builtin.toml`）只有终端、编辑器、合成器、GTK/Qt 与 KColorScheme 等 22 项，没有 fcitx5；官方文档全树搜 `fcitx` 无结果，社区模板与 260 个社区插件目录里也没有输入法主题，v5 同样没有 v4 那种用户自定义模板入口。二进制里唯一的 fcitx 代码是 `fcitx_status.cpp`，仅为顶栏的输入法状态指示。因此候选窗只能靠本脚本自行同步，数据源只能取 KColorScheme 模板的产物。
- **范围：** 只使用已由 `fcitx5-configtool` 引入的 `libplasma`、`kconfig` 与 `kcolorscheme` 库，以及只用于重着色候选项 PNG 的 ImageMagick；不会安装或启动 Plasma Shell、KWin 或其他 KDE 桌面服务。同步 service 不直接由 `graphical-session.target` 启动，而仅由 path unit 在 shell 写入色表后触发；DMS 层若同时把同步 service 作为 target 成员并声明 `After=dms.service`，systemd 会形成排序循环并丢弃 DMS 的启动任务。Noctalia 层对 `noctalia.service` 只用 `After` 排序，它不是 target 成员，因此没有这个问题。
- **选中候选词的文字颜色：** 候选词的文字颜色只由 `theme.conf` 的两个键决定：未选中用 `[InputPanel]` 的 `NormalColor`，选中用 `HighlightCandidateColor`（`inputwindow.cpp` 的 `table[highlight][type]`，`highlight` 为真时取后者）。生成器默认把两者写成同一个值，所以原本无需干预。此前脚本按「选中项用强调色」的想法把 `HighlightCandidateColor` 覆盖成选择前景色（强调色），但选中项背后的高亮块是 `highlight*.png` 这样一张 30% alpha 的位图叠在半透明面板上，实测合成底色远浅于纯强调色，深色桌面上强调色对它只有约 `1.7:1`，比修复前的白字还差。现改为让 `HighlightCandidateColor` 复用生成器算好的 `NormalColor`（用 `kreadconfig6` 按组读取，避免 `sed` 命中同名键），选中与未选中文字始终同色，深色主题白字、浅色主题黑字。实测四种组合（两层的深浅配色）最差 `5.2:1`，均过 WCAG AA；同一个值也用于候选词标签与注释（分别回退到 `HighlightCandidateText` 及其 60% alpha 版本）。**`HighlightColor` 与 `HighlightBackgroundColor` 不要跟着改**：它们服务 preedit 高亮（`TextFormatFlag::HighLight` 只由键盘引擎的客户端预编辑设置，且其 pango 背景是不透明的 `HighlightBackgroundColor`），那里强调色前景仍有约 `7:1`，因此继续用选择前景/背景色。注意 classicui 会跨配置重载缓存 `NormalColor`，改色依赖脚本末尾已有的 `Controller1.Restart`。
- **高分辨率（@Nx）资源的坑：** fcitx5 `5.1.23` 起支持按显示缩放加载高分辨率位图（[fcitx5#1688](https://github.com/fcitx/fcitx5/pull/1688)，`theme.cpp` 的 `loadScaledImages` / `findScaledImage`）：生成器按 `SupportedScale` 额外写出 `highlight@2x.png` 等变体，classicui 再用 `ceil(显示缩放)` 选图。笔记本 eDP-1 为 `scale 1.5`（`~/.config/niri/dms/outputs.kdl`，由 DMS 运行时管理；Noctalia 桌面的缩放写在 `hosts/<host>/desktop/noctalia-with-niri/niri-host.kdl`），`ceil(1.5) = 2`，因此**实际生效的是 `@2x` 变体**，而非 `highlight.png`。修复前的 `mogrify` 只重着色 `highlight/highlight.png`，`@2x` 保持生成器原始的 breeze 蓝（`#3daee9`），表现为深浅色同步与强调色在候选窗上"失效"。现改为用 `highlight*.png` 通配逐个变体重着色。排查时注意：生成器的配色取自私有 Plasma 主题的 `colors` 文件，与 `~/.config/kdeglobals` 无关（已用注入实验证伪"KDE 遗留配置污染生成结果"的假设）。
- **移除条件：** 桌面 shell 提供原生 Fcitx5 模板（Noctalia 上游加入后即可删掉本层脚本），或 Fcitx5 的 Plasma 主题能直接根据 `org.freedesktop.appearance color-scheme` 选择浅/深资源。
- **复查方法：** 暂停 path unit 后切换 shell 深浅色，确认候选窗不再变化；恢复后运行本层的 service（`systemctl --user start fcitx5-dms-theme-sync.service` 或 `fcitx5-noctalia-theme-sync.service`），检查 `~/.local/share/fcitx5/themes/dms-plasma/panel.png` 的背景随模式切换。**同时检查 `@Nx` 变体**：`highlight.png` 与 `highlight@2x.png` 的中心像素必须同为用户强调色（`magick highlight@2x.png -format '%[pixel:p{100,100}]' info:`），只查 `highlight.png` 会漏掉本坑。**再核对高亮文字**：`kreadconfig6 --file ~/.local/share/fcitx5/themes/dms-plasma/theme.conf --group InputPanel --key HighlightCandidateColor` 必须与同组 `NormalColor` 相等（深色配置为 `#fcfcfc`、浅色为 `#232629`），若等于 `Colors:Selection/ForegroundNormal` 就说明又回到文字压在 30% alpha 高亮块上的低对比状态。切换桌面后（例如从 `kde-plasma` 回到 `dms-with-niri`，或换到 `noctalia-with-niri`）需手动跑一次该 service 刷新残留的主题文件。

### Niri 配色改用自定义模板而非上游 `niri` 内置模板（Noctalia 层）

- **位置：** `modules/desktop/noctalia-with-niri/niri-palette.kdl`（载荷副本）与 `default.nix` 里的自定义模板 `niri-colors`；消费方是 `niri-config.kdl` 开头的 `include "noctalia.kdl" optional=true`，`niri.nix` 在构建期渲染并校验它。
- **影响：** Noctalia 5.2.1 的内置 `niri` 模板（`share/noctalia/assets/templates/niri/`）除渲染调色板外还有副作用：`apply.sh` 会把 `include "noctalia.kdl"` 追加到 `$XDG_CONFIG_HOME/niri/config.kdl`，`undo.sh` 会删掉该 include 并 `rm -f` 调色板文件；输出路径固定为 `~/.config/niri/noctalia.kdl`。而 `~/.config/niri/` 属于 `dms-with-niri`（决策 1：DMS 拥有该目录），在 Noctalia 会话里写入它会让两个桌面互相污染配色，切回 DMS 后 DMS 的配色会被 Noctalia 的 include 覆盖。
- **当前处理：** 不启用该内置模板，把它的载荷原样复制为本层的 `niri-palette.kdl`，声明为等价的自定义模板并重定向输出到本层自己的 `~/.config/niri-noctalia/noctalia.kdl`。自定义模板不带任何 hook，因此不会触碰其它目录。niri 的 focus-ring、窗口边框、tab-indicator 与 recent-windows 高亮由此跟随配色。
- **界面里仍能重新打开它：** 设置界面的模板页勾选内置 `niri` 会跑 `apply.sh`，把 include 追加进 DMS 的 `~/.config/niri/config.kdl` 并写出 `~/.config/niri/noctalia.kdl`，对本会话没有任何效果（本会话读 `~/.config/niri-noctalia/config.kdl`），只会在切回 DMS 时把 Noctalia 配色带过去。取消勾选会跑 `undo.sh`，由它删掉 include 与调色板文件，因此清理也跟着界面走；本层 `builtin_ids` 不含 `niri` 只对没有 `settings.toml` 的新设备生效，本机要生效必须在界面里取消勾选。
- **两个易踩的坑：** 其一，niri 的相对 include 按**传给 niri 的那条路径所在目录**解析，而 Home Manager 装的是指向 store 的软链，实测解析基准是软链所在目录（`~/.config/niri-noctalia/`）而非 store 里的真实文件所在目录，所以 `output_path` 与该 include 名必须对齐；构建期用「两个文件都就位时不得出现 `optional include not found`」断言这一点，因为可选 include 缺失只警告、退出码仍为 0，改名后会无声退回默认配色（`#7fc8ff` / `#505050` / `#9b0000`）。其二，模板引擎会对**整份文件**做词法分析，注释里的 `{{...}}` 也会被当成表达式，解析失败时它干脆不写文件，会话里不留任何错误，只能在构建期渲染一次才能发现。
- **残留：** Noctalia 没有 `undo_hook` 之类的机制，切回 `dms-with-niri` 时 `~/.config/niri-noctalia/noctalia.kdl` 不会被删除。该文件对 DMS 惰性（DMS 不设 `NIRI_CONFIG`，读自己的 `~/.config/niri/config.kdl`），且其中的 `layout { border { ... } }` 只改颜色、不会打开边框，建议切换后手工删除。
- **上游：** Noctalia 5.2.1 的 [内置模板目录](https://github.com/noctalia-dev/noctalia/tree/main/assets/templates/niri)（`niri.kdl` / `apply.sh` / `undo.sh`）；niri 的 [Include 文档](https://yalter.github.io/niri/Configuration:-Include.html)（`optional=true`、相对路径基准、缺失时监视并在文件出现后重载）。
- **移除条件：** 上游模板支持自定义输出路径与关闭 include 副作用（例如不再向 `niri/config.kdl` 追加 include，或输出目录可配置），即可改回内置模板并删掉本层的载荷副本、自定义模板与可选 include。
- **复查方法：** `nix build .#nixosConfigurations.vmware.config.system.build.toplevel` 应能渲染载荷并通过 `niri validate`；会话内 `ls -l ~/.config/niri-noctalia/noctalia.kdl` 应有该文件且 `grep active-color` 为当前强调色（由壁纸生成，深色 `m3-content` 下为 `#bcc2ff`）；`journalctl --user -u niri | grep "optional include not found"` 在首次渲染后应为空；`niri msg action load-config-file` 后窗口边框颜色应随之更新。注意没有查询主题的 IPC，颜色只能用截图比对默认值判断。

### 深浅色切换时由钩子同步壁纸（Noctalia 层）

- **位置：** `modules/desktop/noctalia-with-niri/theme-auto.nix` 的 `hooks.started` 与 `hooks.theme_mode_changed`（两者指向同一个 `writeShellScript` 产物）；模式与坐标在同目录 `default.nix` 与 `theme-auto.nix` 声明，壁纸图由 `modules/home/defaults/theme.nix` 安装。
- **影响：** Noctalia 5.2.1 的壁纸与主题是两个独立服务。`theme.mode = "auto"` 按日出日落翻转调色板，但壁纸路径只在三个地方被写入：图形选择器、`switchWallpaperTo()`，以及可选的轮播自动化（`[wallpaper.automation] enabled`，默认关闭）；`wallpaper.directory_light` / `directory_dark` 只决定这两处挑图的**目录**，不参与应用。因此模式翻转后调色板随新壁纸重新生成，屏幕上的图却仍是旧的那张，深浅两张壁纸无法只靠声明式配置切换。`[wallpaper.default]` 只有一个 `path` 键，没有 `path_light` / `path_dark` 之类的成对配置。
- **当前处理：** 钩子脚本向运行中的 shell 查询**已解析**的模式（`noctalia msg theme-mode-get` 返回 `light` 或 `dark`，`auto` 不会被原样返回），据此在两张图之间挑选，再用 `noctalia msg wallpaper-set` 应用。两个钩子缺一不可：`theme_mode_changed` 的环境里有 `NOCTALIA_THEME_MODE`（管理器在 fork 之后才 unset，子进程读得到），但它在**启动时不触发**，因为该回调要求「已知上一个模式」，会话的首次解析没有上一个模式；`started` 恰好补上登录时的同步（它在 IPC 初始化之后触发），且不带环境变量，所以脚本回落到查询运行中的 shell。应用前先与 `wallpaper-get` 比对，路径相同就直接退出，避免无谓地写 `settings.toml`。`noctalia` 以 store 绝对路径调用，不依赖钩子继承到的 `PATH`。
- **已知副作用：** `wallpaper-set` 会把结果持久化到 `~/.local/state/noctalia/settings.toml`（`[wallpaper.default]`、`[wallpaper.last]` 与逐输出的 `[wallpaper.monitors.<connector>]`），而该文件优先级高于本层的 `config.toml`。所以图形界面里手动选的壁纸会在下一次模式翻转时被覆盖，这是选择「用钩子强制切换」时接受的取舍；不接受就只能放弃自动换图。
- **上游：** Noctalia 5.2.1 的壁纸服务与主题服务（`src/shell/wallpaper/`、`src/theme/`）；钩子种类与触发条件见官方文档的 Hooks 一节。上游尚未提供「模式变化时重新应用壁纸」或按模式成对声明壁纸的能力。
- **移除条件：** 上游让模式切换自动重新应用与当前模式匹配的壁纸（例如 `[wallpaper]` 增加成对的深浅路径，或主题服务在翻转调色板时一并切换壁纸图），即可删除 `theme-auto.nix` 里的两个 hook，只保留坐标。
- **复查方法：** 会话内临时改模式验证同步（会写 `settings.toml`，试完记得改回 `auto`）：

  ```fish
  noctalia msg theme-mode-get            # 当前解析结果
  noctalia msg theme-mode-set light      # 触发 theme_mode_changed
  noctalia msg wallpaper-get             # 应为 wallpaper-light.png
  noctalia msg theme-mode-set auto
  ```

  钩子改到 `started` 的登录同步只能靠重启会话验证：`journalctl --user -u noctalia | grep -i hook` 不应出现 `hook '...' command failed`，`noctalia msg wallpaper-get` 应与当时 `theme-mode-get` 的结果对应。修复本条后 `[theme] mode` 残留值仍需人工清一次（见 AGENTS.md「深浅色自动切换」）。

### Noctalia 设置界面的改动按项固化进 `config.toml`（Noctalia 层）

- **位置：** `modules/desktop/noctalia-with-niri/default.nix` 的 `programs.noctalia.settings`（外观与控件偏好）与 `theme-auto.nix` 的 `location`。
- **影响：** 设置界面把改动写进 `~/.local/state/noctalia/settings.toml`，该文件在 `~/.config/noctalia/*.toml` 之后读取并逐键覆盖，因此界面改动只留在改过的那台机器上，换机或重装即丢失。而界面写出的常常是整个控件块的完整快照，照抄会把与上游默认相同的键一起固化，还会把运行时状态（当前壁纸、某台显示器的锁屏组件几何）一起钉死，所以必须按项筛选。
- **当前处理：** 只固化「与上游默认不同且与设备无关」的项，逐项经用户勾选后写入。筛法是用空的 `XDG_CONFIG_HOME`/`XDG_STATE_HOME` 跑 `noctalia config export full` 取纯默认，再与 `settings.toml` 逐键比对（实测 63 个键里 58 个与默认不同），按「可直接移植 / 有副作用 / 需拍板」分组后由用户决定。已固化：状态栏（全透明、方角、无端边距、接触阴影、`media` 移到中部）、Dock（启用、自动隐藏、仅当前显示器、关闭占位、显示指示点）、热区（启用、左上角窗口切换器）、锁屏模糊桌面、Shell（Sarasa UI SC、秒级时间、面板玻璃质感、遥测跟随界面开启）、时钟/电池/媒体/网络四个控件的偏好，以及内置模板增补 `btop` 与 `starship`。位置按用户选择固化为 `address = "赣州"`，坐标同步取该地址的地理编码结果作为离线兜底。
- **刻意不固化的部分：** `wallpaper.default` / `wallpaper.last` / `wallpaper.monitors.*` 是运行时状态且带 `/home/<user>` 绝对路径，由 `theme-auto.nix` 的钩子按深浅色管理；锁屏组件几何绑定 `eDP-1` 与该机的布局尺寸，换机会错位，确需固化时按主机放 `hosts/<host>/desktop/noctalia-with-niri/`；`config_version` 是状态文件版本号；`shell.app_icon_color` 与上游默认一致。
- **边界：** 固化只对**没有** `settings.toml` 的新设备生效。本机已被界面写过的键仍是界面那份赢，要改现值必须在界面里改，或删掉 `settings.toml` 里对应键；`builtin_ids` 去掉内置 `niri` 模板也要在界面里取消勾选才对本机生效（该模板的副作用见「Niri 配色改用自定义模板而非上游 `niri` 内置模板」）。
- **复查方法：** 重建后 `noctalia config validate ~/.config/noctalia/config.toml` 应为 `Config is valid`（该文件是 Home Manager 生成的只读符号链接）。要确认新设备真正拿到的值，用临时目录预演：把同一份文件复制为 `/tmp/nc/noctalia/config.toml`，再跑 `XDG_CONFIG_HOME=/tmp/nc XDG_STATE_HOME=/tmp/ns noctalia config export full`，与空配置目录下的同一命令输出逐键比对；本机的 `settings.toml` 优先级更高，直接 `noctalia config export` 看不到这里的结果。

### Noctalia 社区主题模板需要每台设备下载一次（Noctalia 层）

- **位置：** `modules/desktop/noctalia-with-niri/default.nix` 的 `theme.templates.community_ids`。
- **影响：** 社区模板不随 `noctalia` 包分发，而是设置界面从社区目录下载后缓存到 `~/.local/state/noctalia/community-templates/<id>/`（每个目录一份 `template.toml` 加 `.noctalia-cache.json`，根目录另有 `catalog.json`）。`community_ids` 只决定「缓存里哪些模板参与渲染」：二进制里对应分支是 `community template '{}' is not cached yet`，命中即跳过，声明 id 不会触发下载，`noctalia msg` 也没有按 id 预取的子命令（只有 `templates-apply`）。因此新设备上这 22 个模板在下载前是静默缺失的，表现为这些应用的配色不跟随桌面。
- **当前处理：** 仍把 id 清单声明进 `config.toml`，让设备下载完成后立刻得到同一组模板、不必逐个勾选；下载这一步无法声明式复现，需在设置界面的模板页操作一次。
- **上游：** Noctalia 5.2.1 的社区模板目录（缓存根目录的 `catalog.json` 记录来源）；上游未提供「按 id 预取」的 CLI，也没有把社区模板打进包的渠道。
- **移除条件：** 上游提供声明式安装方式（nixpkgs 打包社区模板，或 CLI 支持按 id 下载），即可改为随包装安装并把 `community_ids` 留给默认值。
- **复查方法：** 新设备进过一次设置界面的模板页后，`ls ~/.local/state/noctalia/community-templates` 应包含 `community_ids` 列出的每个 id；`noctalia msg templates-apply` 后 `journalctl --user -u noctalia | grep -i "not cached"` 应为空。

### 声明式 niri 配置里留一枚可写的 `custom.kdl`（Noctalia 层）

- **位置：** `modules/desktop/noctalia-with-niri/niri-config.kdl` 末尾的 `include "custom.kdl" optional=true`；模板载荷是同目录的 `niri-custom-default.kdl`，播种逻辑在同目录 `niri.nix` 的 `home.activation.seedNiriCustomConfig`；备份往返是 `scripts/backup.sh` 的 `niri-custom-snapshot` 与 `niri-custom-apply`（脚本在 `user_profiles/mooling/niri-noctalia/`）。
- **影响：** 本层 niri 配置是声明式的（见 AGENTS.md「niri 配置隔离」），`config.kdl`、`host.kdl` 与渲染出的 `noctalia.kdl` 都是 store 里的只读符号链接或运行时文件，没有地方临时叠加一项偏好（例如试一下新的 `gaps`、改一条 `binds`）。这正是决策 1 拒绝把 niri 配置整体纳入声明式管理的原因，只是本层为配置隔离又把它们收回了声明层，所以需要一个受控的出口。
- **当前处理：** 新增 `custom.kdl`，约定它由用户手写、不归 Home Manager 管理，并以 `optional=true` 放在两个 include 之后，因此优先级最高、缺失也不致命。它**不能**写进 `xdg.configFile`：那会变成只读 store 符号链接，与「可写」的目的相反。Home Manager 只在文件缺失时从 `niri-custom-default.kdl` 播种一份带注释的模板，之后永不改写，删掉即可恢复模板。构建期把这份模板一并 stage 进 `niri validate` 的校验目录，因此模板自身或注释掉的示例写坏语法会在构建阶段暴露，而不是等到登录时。
- **模板末尾那枚空 `layout` 块不可删：** NiriMod 把注释存成挂在已解析节点上的 trivia（`KdlNode.leading_trivia`），文件里一个节点都没有时没有可挂载的对象，首次保存会把整份注释连同文件一起压成单行（实测 53 行、47 条注释 → 1 行、0 条注释）。模板因此以一个空 `layout {` `}` 收尾，它解析后不含任何属性，`merge!` 只合并 `Some` 字段，而且该块来自 include（`recursion != 0`），连 `lib.rs` 里「主配置出现 `border` 且未写 `on`/`off` 时强制开边框」的分支都不会进入，所以它是惰性的。它必须放在**所有注释之后**：注释是挂到**下一个**节点的前置 trivia，锚点若放开头，其后的注释会随新节点一起被搬到文件末尾。
- **合并语义的限制（写 `custom.kdl` 前必读）：** niri 的 include 按位置原地展开、后者胜出，但各节的合并粒度并不一致。`input`、`cursor`、`layout`、`debug`、`blur`、`animations`、`gestures`、`overview` 是属性级合并，可以只写要改的项；而 `input` 下的 `touchpad`、`mouse`、`trackpoint`、`trackball` 与 `keyboard` 的 `xkb` 走的是整值替换，只写 `touchpad { tap }` 会丢掉该块其余设置。`binds` 按**按键**覆盖（删掉冲突键再新增，其余键保留，所以适合只改一两条）；`environment` 追加、同名后者胜出；`screenshot-path`、`prefer-no-csd` 取最后一次出现的值；`window-rule`、`layer-rule` 按顺序追加并叠加，但**无法取消**上游已设的属性。`output` 与 `workspace` 虽然也追加，运行时却取第一条名字匹配的块（`Outputs::find` 用 `iter().find()`），因此在 `custom.kdl` 里再写一个同名 `output` 块会被静默忽略，改输出设置必须直接改 `hosts/<host>/desktop/noctalia-with-niri/niri-host.kdl`。
- **启动与重载的失败行为不同：** `custom.kdl` 缺失只有一条 `WARN niri_config: optional include not found`，退出码仍为 0；文件存在却语法错误则 `niri validate` 退出码为 1，`optional=true` 挡不住解析失败。热重载遇到解析错误会保留当前配置并弹出提示，但**下次登录会退回 niri 内置默认配置**，等于丢掉整个声明层，所以这里的语法错误比缺文件严重得多。`scripts/backup.sh niri-custom-apply` 因此在覆盖前先校验：把快照放进临时目录，并与真实的 `config.kdl`、`host.kdl`、`noctalia.kdl` 一起跑 `niri validate`（用 `cp -L`，否则符号链接会让校验读到 store 里的错误路径），校验不过直接拒绝，不动现场文件。
- **上游：** niri 的 [Include 文档](https://yalter.github.io/niri/Configuration:-Include.html)（`optional=true`、位置展开、后者覆盖前者）；合并粒度与「首个 output 块生效」来自 niri-config 源码的 `merge!` / `merge_clone!` 宏与 `Outputs::find`（`niri-config/src/lib.rs`、`macros.rs`、`output.rs`）。
- **移除条件：** niri 提供官方的用户级覆盖机制（例如独立于主配置的 drop-in 目录，且各节均为属性级合并），或 Home Manager 的 niri 模块支持声明一个可写的本地覆盖文件，即可删除 include、播种激活步骤与模板副本。
- **复查方法：** `nix build .#nixosConfigurations.vmware.config.system.build.toplevel` 应通过构建期的 `niri validate` 与「两个 include 均已就位时不得出现 `optional include not found`」断言；会话内 `ls -l ~/.config/niri-noctalia/custom.kdl` 应是普通可写文件（不是指向 store 的符号链接）；`niri validate -c ~/.config/niri-noctalia/config.kdl` 应为 `config is valid`；改一行后可观察 `journalctl --user -u niri | grep "loaded config"` 的 500 毫秒轮询热重载是否生效。手工验证 `output` 首块生效时，在 `custom.kdl` 里加一个同名 `output` 块，`niri validate` 仍然退出 0，这正是它静默失效的证据。

### NiriMod 的 `nirimod` 命令默认指向可写的 `custom.kdl`（Noctalia 层）

- **位置：** `modules/desktop/noctalia-with-niri/packages.nix` 里的 `nirimodCustom`（对 `pkgs.nirimod` 做 `overrideAttrs`，追加 `makeWrapperArgs`）；上游包在锁定 nixpkgs 的 `pkgs/by-name/ni/nirimod/package.nix`，版本 `0-unstable-2026-09-19`。
- **影响：** Noctalia 没有窗口规则的图形编辑器，上游也明确不做。`noctalia-dev/noctalia` 的功能请求 [#4268](https://github.com/noctalia-dev/noctalia/issues/4268)（为合成器配置文件加一个设置页）已被关闭为 `NOT_PLANNED`，理由是同时支持七种以上合成器配置文件的成本过高，维护者给出的替代方案正是 Niri 用 NiriMod。Noctalia 的插件市场目前也没有等价插件（仅「社区插件即将推出」），`noctalia --help` 的子命令只有 `completions`、`config`、`dmenu`、`firefox-theme`、`msg`、`plugins`、`theme`。
- **当前处理：** 装 NiriMod，但让 `nirimod` 命令本身默认打开 `~/.config/niri-noctalia/custom.kdl`。做法是覆盖 `makeWrapperArgs` 注入 `--add-flags "--config=..."`，不动上游的 `preFixup`（它负责把 `gappsWrapperArgs` 追加进 `makeWrapperArgs`，覆盖属性时用 `(old.makeWrapperArgs or []) ++ [...]` 即可保留）。上游 `bin/nirimod` 是 `makeWrapper` 产物，真实入口是 `bin/.nirimod-wrapped`；桌面项 `io.github.nirimod.desktop` 的 `Exec=nirimod`，所以图形启动与命令行走同一份包装脚本。
- **为什么指向单文件后是安全的：** 传入 `--config` 后 `kdl_parser.set_paths()` 把 `NIRI_CONFIG` 设为该文件、`_config_dir` 设为其父目录，由于该文件没有 include，`is_multi_file` 为假，保存走 `save_niri_config()` 单文件分支，只写 `custom.kdl`。多文件分支则会重写 include 指向的每个文件，其中 `config.kdl`、`host.kdl` 都是 store 里的只读符号链接，实测报 `OSError: [Errno 30] Read-only file system`，而且 `custom.kdl` 在失败前已被写大，没有回滚。
- **两个必须记住的传参事实：** 其一，`makeWrapper` 把每个 `--add-flags` 的值**原样**交给程序，用 `lib.escapeShellArg` 包一层会送出字面引号，`strace` 实测 argv 为 `['--config=...']`（含引号），GLib 只把带引号的那项当位置参数丢掉，注入静默失效。其二，`--add-flags` 的值按空白拆分成多个参数，路径含空格会碎成两段，本机 `XDG_CONFIG_HOME` 是 `/home/mooling/.config` 所以不受影响；要兼容带空格的路径只能改用 `--add-flags` 之外的机制（例如自定义 `postFixup` 手写包装脚本）。
- **覆盖顺序：** 注入的 `--config` 排在用户参数之前，而 GLib 对重复出现的同名选项取**最后一个**，因此 `nirimod -c other.kdl` 仍能临时改目标。GUI 里持久化的 `config_path` 设置优先级低于命令行，包装注入的这一项始终生效。
- **上游：** [srinivasr/nirimod](https://github.com/srinivasr/nirimod)（MIT，GTK4/libadwaita）；窗口规则页面在 `nirimod/pages/window_rules.py`（Add Window Rule / Add Layer Rule）。相邻替代：`xoalt/mangomod`（面向 mangowc）、`enricolo4/niri-config-gui`，功能均不及 NiriMod。
- **移除条件：** Noctalia 提供内置的窗口规则编辑器（或插件市场出现等价插件），即可删掉这个覆盖；届时应优先用上游图形编辑器写同一份 `custom.kdl`。
- **复查方法：** `nix build .#nixosConfigurations.vmware.config.system.build.toplevel` 后 `strace -f -e trace=execve -s 400 "$(command -v nirimod)" --help 2>&1 | grep nirimod-wrapped`，参数列表应含 `--config=/home/<user>/.config/niri-noctalia/custom.kdl` 且**不含**引号；`nirimod --version` 应为 `NiriMod 0.5.0`。图形侧保存后跑 `./scripts/backup.sh niri-custom-snapshot mooling` 再 `git diff`，应只出现新增的节点而注释仍在；`ls -l ~/.config/niri-noctalia/config.kdl` 应仍是 store 符号链接、内容未被改写。

### Wine 的 PipeWire 与 WoW64 兼容层

- **位置：** `modules/system/packages.nix` 的 `pulseaudio`；`modules/optional/wine.nix` 的 `wine64-symlink`、`WINEDLLOVERRIDES` 与 `QT_PLUGIN_PATH`；`modules/home/defaults/wine.nix` 和生成的 Fish 配置中的同一变量。
- **影响：** 禁用 `winealsa.drv`，改由 PipeWire 的 PulseAudio 兼容层处理音频，以避免 `winecfg` 枚举音频设备时卡死；同时伪造 `wine64`，满足 WoW64 模式下的 `winetricks` 查找。
- **相关提交：** `89f35ae`（`fix: add pulseaudio and disable winealsa to prevent winecfg audio tab freeze`）；`6201ec7`（`fix: add wine64 symlink for winetricks WoW64 compatibility`）。
- **移除条件：** 当前 Wine 在 PipeWire 下运行 `winecfg` 不再卡死，且 WoW64 的 `winetricks` 可直接找到实际的 `wine64` 可执行文件。
- **复查方法：** 在测试环境中移除上述覆盖，运行 `winecfg` 并执行实际使用的 WoW64 `winetricks` 流程；两者通过后再删除兼容层。

### Wine 应用的托盘图标经 XEmbed 桥接进入系统托盘

- **位置：** `modules/optional/xembed-sni-proxy.nix`（由 `modules/home/mooling/default.nix` 导入）。
- **影响：** Wine 程序调用 `Shell_NotifyIcon` 只能把托盘图标放进 XEmbed 系统托盘，而 niri 不提供托盘宿主：无人认领 X 服务器上的 `_NET_SYSTEM_TRAY_S0` 选择时，图标窗口会变成独立的 Xwayland 窗口在布局里漂浮。该单元运行 plasma-workspace 自带的 `xembedsniproxy`，由它认领选择、让应用把图标嵌入进去，再把每个图标转成 StatusNotifierItem，Noctalia（或 DMS）的托盘即可像原生托盘项一样显示。nixpkgs 没有独立的 `xembed-sni-proxy` 包，其 `snixembed` 是反方向（StatusNotifierItem 转 XEmbed，服务 X11 窗口管理器），因此二进制取自 `plasma-workspace`；该闭包本就在系统闭包内，不新增下载。
- **相关提交：** `e5462e1`（`feat(tray): bridge XEmbed tray icons into the StatusNotifierItem tray`）。
- **已知取舍：** XEmbed 图标是小位图，保持原始 22 到 24 像素尺寸，在 HiDPI 输出上偏软；应用托盘的右键菜单仍是 Xwayland 窗口，niri 会把它当作普通窗口显示在指针附近，而不是弹出菜单。代理启动前已在运行的应用需要重启，图标才会移入托盘。
- **移除条件：** nixpkgs 提供独立的 `xembed-sni-proxy` 包，或不再使用需要托盘图标的 X11/Wine 应用。
- **复查方法：** 重建后 `systemctl --user status xembed-sni-proxy` 应为 active；运行一个带托盘图标的 Wine 应用，`busctl --user get-property org.kde.StatusNotifierWatcher /StatusNotifierWatcher org.kde.StatusNotifierWatcher RegisteredStatusNotifierItems` 应出现对应项，且图标显示在 Noctalia 栏的托盘里。

### Apollo 串流模块被永久移除

所有串流相关的 flake 输入、模块代码均已被删除，用户不再使用。

相关提交： `bd9bd97`（`fix!: remove apollo/sunshine streaming service completely`）

### Home Manager 冲突备份后缀

- **位置：** `modules/core.nix` 的 `home-manager.backupFileExtension = "backup"`。
- **影响：** 激活时会将与 Home Manager 目标文件冲突的既有文件重命名为 `.backup`；原用于处理由 DMS/Niri 运行时管理的 `config.kdl` 冲突。
- **相关提交：** `64177f6`（`fix: add home-manager.backupFileExtension to resolve config.kdl conflicts`）；`a383c84`（`fix!: stop declaratively managing DMS and NvChad runtime config`）移除了最初的配置冲突来源。运行时 Niri/DMS 配置已不再由 Home Manager 声明式管理，因此需重新确认该后缀是否仍有必要。
- **移除条件：** 不存在其他需要保留的 Home Manager 目标文件冲突，且移除该选项后的 Home Manager 激活成功。
- **复查方法：** 临时移除该选项后执行常规 `nixos-rebuild switch`；若激活报出文件冲突，先确认该目标文件是否应由 Home Manager 接管，再决定是否保留该后缀。

### 登录器不能用 noctalia-greeter（wlroots 处理不了 vmwgfx 的 dmabuf 缓冲）

- **位置：** `modules/desktop/noctalia-with-niri/greeter.nix`：选用 nixpkgs 自带的 `services.displayManager.dms-greeter`（`compositor.name = "niri"`），并用 `configHome` 复用 `~/.config/DankMaterialShell` 里既有的外观；同文件另启用 `getty@tty2` 作为逃生通道。
- **影响：** noctalia-greeter 自带 `noctalia-greeter-compositor`（wlroots 0.20.2）。在 VMware 的 vmwgfx + SVGA3D 上它无法妥善处理 greeter 客户端交来的 dmabuf 缓冲：`close_all_bo_handles()`（`backend/drm/fb.c:107`）对 GBM 已关闭的 GEM handle 再关一次，vmwgfx 返回 `EINVAL`（日志为 `drmCloseBufferHandle failed: Invalid argument` 与 `[types/wlr_linux_dmabuf_v1.c:223] Failed to close buffer handle for plane 0`），随后合成器主动向客户端报协议错误（greeter 侧 `Wayland dispatch_pending failed: protocol error 7`），greeter 退出，greetd 报 `greeter exited without creating a session` 且**不重试**，表现为开机日志滚完后黑屏。
- **两次绕过均失败（记录以免重走）：** 第一版导出 `WLR_SCENE_DISABLE_DIRECT_SCANOUT`、`WLR_DRM_NO_MODIFIERS`、`WLR_NO_HARDWARE_CURSORS`（三个名字逐个核对存在于 `libwlroots-0.20.2`），它们碰不到客户端缓冲导入，仍复现；第二版让两侧都离开 dmabuf（合成器 `WLR_RENDERER=pixman`、客户端 `LIBGL_ALWAYS_SOFTWARE=1`），同样复现。因此不再在该合成器上尝试。
- **当前处理：** 改用 `dms-greeter`。它把界面跑在 **niri** 里，而 niri 基于 smithay 而非 wlroots，在这台 GPU 上正常（世代 27 的 DMS 会话即为长期证据）；`configHome` 指向用户家目录后，登录界面直接读现有的 `~/.config/DankMaterialShell/settings.json`、`~/.local/state/DankMaterialShell/session.json` 与 `~/.cache/DankMaterialShell/dms-colors.json`，外观与既有配置一致。Noctalia 会话本身不受影响。
- **逃生通道：** 默认只在 tty1 起 getty，而 tty1 归 greetd，登录界面出问题时没有控制台可登录，因此启用 `getty@tty2`。注意**仅设 `enable = true` 不够**：NixOS 生成的模板实例单元没有 `[Install]` 段，`getty.target.wants/` 下不会出现链接，systemd 从不启动它（世代 29 实测如此）；必须同时声明 `wantedBy = [ "getty.target" ]`（世代 30 起已在 etc 中确认链接存在）。
- **上游：** [noctalia-greeter](https://github.com/noctalia-dev/noctalia-greeter)（自带合成器 1.6.0）、wlroots 0.20.2、Mesa 的 `drmCloseBufferHandle`（[wlroots#3234](https://github.com/swaywm/wlroots/issues/3234) 即引入该调用的改动）。上游未见 VMware 报告，同类症状只有 [#149](https://github.com/noctalia-dev/noctalia-greeter/issues/149)。
- **移除条件：** noctalia-greeter 或 wlroots 能在 vmwgfx 上正常导入客户端缓冲（启动日志不再出现上述两条错误且登录界面可用），即可改回 `services.displayManager.noctalia-greeter` 并删掉本层的 dms-greeter 接线；届时若已不需要 DMS 生态，`dms-greeter` 亦可一并移除。`getty@tty2` 可在登录界面不再脆弱后移除。
- **复查方法：** 重启后确认登录界面出现，`journalctl -b | grep -E "dms-greeter|greeter exited"` 无异常，`systemctl is-active getty@tty2` 为 active。仍黑屏时 Ctrl+Alt+F2 登录 tty2，跑 `~/check.sh`，或直接 `niri-session` 进入桌面。

### setuid 的 `pkexec` wrapper（nixpkgs 默认关闭）

- **位置：** `modules/system/polkit.nix` 的 `security.polkit.enablePkexecWrapper = true`（两个主机都导入该模块）；对应的免密规则在 `modules/desktop/dms-with-niri/system.nix` 与 `modules/desktop/noctalia-with-niri/system.nix`。
- **影响：** `gpu-screen-recorder` 的 nixpkgs wrapper 会把 `/run/wrappers/bin` 前置进 `PATH`，其二进制在 `gsr-kms-server` 缺少 `cap_sys_admin` 时通过 `pkexec` 提权（二进制内有 `pkexec` 与 `gsr-kms-server is missing sys_admin cap and will require root authentication` 字符串）。这个 nixpkgs 把该 wrapper 改成可选：`security.polkit.enablePkexecWrapper` 默认 `false`，`/run/wrappers/bin/` 里只有 `sudo` 与 `sudoedit`，于是 pkexec 不存在，桌面层那条免密规则永远不会被 polkit 询问到，录屏提权必然失败。
- **当前处理：** 在共享系统模块里显式打开该选项，恢复 pkexec；授权链路不变，操作仍要经过 polkit，只有规则放行或认证代理批准才继续。
- **上游：** nixpkgs 的 `nixos/modules/security/polkit.nix`（`enablePkexecWrapper` 选项，`security.wrappers.pkexec.enable` 直接取自它）；提权方式见 [gpu-screen-recorder](https://git.dec05eba.com/gpu-screen-recorder/about/) 关于 pkexec 与 `setcap cap_sys_admin+ep` 的说明。
- **移除条件：** `gpu-screen-recorder` 不再经 `pkexec` 提权（例如改为给 `gsr-kms-server` 授能力位），或该录屏流程不再使用；此时删除 `modules/system/polkit.nix` 及两个主机导入列表里的对应一行。
- **复查方法：** `ls -l /run/wrappers/bin/pkexec` 应存在并带 setuid 位，`pkexec --version` 能执行。**注意 `hosts/vmware` 无法验证录屏链路**：gsr 只支持 NVIDIA/AMD/Intel，在这台 VM 上会以 `gsr error: unknown gpu vendor: VMware, Inc.` 与 `failed to load opengl` 直接退出，规则无从触发；端到端验证要在有真实 GPU 的主机上做。

### WPS 的更新弹窗在 xwayland-satellite 下无法点击（`wps-update-dialog`）

- **位置：** `modules/optional/wps-update-dialog.nix` 与同目录的 `wps-update-dialog-guard.py`（由 `modules/home/mooling/default.nix` 的 `optionalImports` 导入）。单元名 `wps-update-dialog-guard`。
- **影响：** `wpsoffice-cn` 把「发现新版本，是否更新？」提示画成一个自绘无边框的 X11 对话框：`WM_CLASS` 属于 `et`，`_NET_WM_WINDOW_TYPE` 含 `DIALOG`，`_NET_WM_STATE` 含 `MODAL`，`_MOTIF_WM_HINTS` 关闭装饰。在 xwayland-satellite 下该窗口在 X11 栈序里落在应用主窗口**之下**（实测：弹窗 index 21，同进程另一个标题为「更新」的窗口 index 22，主窗口 index 28），合成器又不向它投递指针输入。于是点击一律被栈顶的主窗口接走，而主窗口已被 `_NET_WM_STATE_MODAL` 禁用，弹窗既点不动也关不掉，整个 WPS 不可用。对弹窗区域做 X11 命中测试时，四个采样点全部落到文档窗口，是该现象的量化证据。
- **当前处理：** `wps-update-dialog-guard` 单元轮询 X 服务器（间隔 0.5 秒），命中上述四属性组合的窗口即发送标准 `WM_DELETE_WINDOW` 客户端消息。该消息由 WPS 自己处理，实测能正常关闭弹窗并让主窗口恢复可用。
- **为什么不去改栈序：** xwayland-satellite 自己拥有栈序，客户端发起的 `XRaiseWindow`、`XLowerWindow` 与 `XConfigureWindow(stack_mode=Above)` 全部被静默忽略（调用后栈序不变且不返回 X11 错误）。「把弹窗提到主窗口之上」这条路在这台机器上走不通，`WM_DELETE_WINDOW` 才是唯一可用的干预点。
- **相关提交：** `3c28cb8`（`fix(wps): close the update dialog that cannot take pointer input`）。
- **已知取舍：** 弹窗仍会先短暂出现再被自动关闭（通常在半秒内），而不是变得可交互；若 WPS 重复弹出，守护也会重复关闭。识别刻意收紧到四个属性同时满足，普通对话框（另存为、字体设置等）不会被误关。
- **上游：** niri 通过 [xwayland-satellite](https://github.com/Supreeeme/xwayland-satellite) 提供 X11 支持；WPS for Linux 的更新提示是闭源二进制，其窗口标志没有可配置项。
- **移除条件：** xwayland-satellite（或 niri）能正确处理这类自绘模态对话框的输入路由，即弹窗可以直接点击和关闭；或 `wpsoffice-cn` 不再弹出该更新提示。届时删除 `modules/optional/wps-update-dialog.nix`、`modules/optional/wps-update-dialog-guard.py`，以及 `modules/home/mooling/default.nix` 中对应的那一行导入。
- **复查方法：** `systemctl --user status wps-update-dialog-guard` 应为 active；启动 WPS 时弹窗应在约一秒内自行消失，`journalctl --user -u wps-update-dialog-guard` 出现 `closing WPS update dialog 'WPS Office'`；弹窗消失后主窗口的单元格应能正常点选、菜单能正常展开。若弹窗仍在且日志无该行，先看日志里是否停在 `X connection problem ... retrying in 5s`，那说明单元没拿到 `DISPLAY`。
