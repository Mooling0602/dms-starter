# 维护清单

记录仓库中依赖上游修复、外部补丁、临时绕过，或临时替代原始包来源的配置。更新 `flake.lock`、升级相关输入或调整覆盖前，应逐项重新评估；已满足移除条件时，删除覆盖并完成对应验证。

## 审查范围

- 检查 `flake.nix` 的所有输入、`nixpkgs.overlays`、`overrideAttrs`、`fetchpatch`、不安全包许可，以及被注释禁用的模块或服务。
- 任何 fork 只要用于替代原本由 Nixpkgs、其他 flake 或上游仓库提供的包，就必须在本文档记录；fork 可以属于任意个人或组织，并不限定为本人的仓库。
- 长期维护的独立配置或包源不因其所有者而自动列入；只有存在明确的上游回归、移除或重新启用条件时才需要记录。

## 输入锁定

### `dms` 固定到指定 rev

- **位置：** `flake.nix` 的 `dms` 输入（URL 末尾为完整 rev）。
- **影响：** `AvengeMedia/DankMaterialShell` 的默认分支是 `master`，其上是对应尚未发布的版本，而 release tag 与 `master` 是**分叉**关系（`v1.6.2` 与 `master` 各有独有提交），因此上游没有可直接跟随的稳定分支。不固定 rev 时，`nix flake update` 会把 DMS 拉到 `master` 任意一处，界面组件与 shell 版本错配会导致界面异常，且问题往往在重建后才暴露。
- **当前处理：** URL 内写死 rev，等价于把 `flake.lock` 的当前状态固化到 `flake.nix`，使 DMS 不受全量 `nix flake update` 影响。固定 rev 同时锁死 DMS 自身的传递输入 `dank-qml-common` - 该 rev 自带的 `flake.lock` 是确定内容，全量更新时不会被一并刷新（同一仓库的 `dankcalendar`、`danksearch` 等仍跟默认分支，会照常更新）。
- **上游：** https://github.com/AvengeMedia/DankMaterialShell
- **移除条件：** 上游提供可跟随的稳定分支或 tag 语义（例如 release 从 `master` 切出而非分叉），且跟随它不会引入未发布变更。
- **复查方法：** 确认 DMS 未被全量更新移动，以及错误版本的传递输入会被纠正回锁定值：

  ```fish
  # 全量更新后 dms 的 rev 应保持不变
  nix flake update && nix flake metadata --json | jq -r '.locks.nodes.dms.locked.rev'
  ```

  升级到新版本时，把 `flake.nix` 中 URL 末尾的 rev 换成目标提交，再运行 `nix flake lock` 让 `flake.lock` 的 `original.rev` 跟上（该步骤只写 `original.rev`，不改变锁定内容），最后重建验证。可用 tag 对应的提交作为参照：

  ```fish
  gh api repos/AvengeMedia/DankMaterialShell/commits/master --jq '.sha'
  ```

## 上游包源替换

### `niri-input-portal` 提供 niri 缺失的 InputCapture 门户后端

- **位置：** `flake.nix` 的 `nix-packages` overlay 条目；`modules/desktop/dms-with-niri/xdg-portals.nix` 的 `xdg.portal.extraPortals`、`xdg.portal.config` 与 `systemd.user.services`；`~/.config/niri/config.kdl` 的 `Mod+Shift+Space` 逃生键（该文件由 DMS/Niri 运行时管理，不由 Nix 声明）。包本体与本地补丁 `fix-eis-device-region.patch` 位于 `Mooling0602/nix-packages` 的 `pkgs/by-name/ni/niri-input-portal/`。
- **影响：** niri 未实现 `org.freedesktop.impl.portal.InputCapture`，而 `xdg-desktop-portal-gnome` 只在 niri 提供 `org.gnome.Mutter.InputCapture` 时才发布该接口，因此 Deskflow、Synergy 3、Input Leap 等在 niri 下作为 server 共享键鼠时会以 `failed to initialize input capture session` 失败。nixpkgs 未收录该后端，故自行打包并跟踪上游 `main`（上游无 tag 与 release）。
- **当前处理：** 包经 `nix-packages` 输入进入 `pkgs`；门户路由在 `common` 与 `niri` 两个 section 中把 `InputCapture` 与 `Clipboard` 指向 `niri-input` - `Clipboard` 必须一并路由，否则剪贴板门户会挂到未创建该会话的后端上，客户端随后陷入 create/destroy 死循环。D-Bus 激活单元在 Home Manager 中显式声明，以去掉上游的 `ConditionEnvironment=WAYLAND_DISPLAY`（条件不成立时 systemd 会静默跳过该单元，D-Bus 只报服务名不可激活）。niri 侧的 `Mod+Shift+Space allow-inhibiting=false` 绑定调用 `niri-input-portal --release`：捕获期间指针被锁、键盘被独占，而 niri 会先于客户端处理自己的绑定，因此这是唯一可靠的逃生出口；`dms setup` 重新生成 `config.kdl` 后需要重新添加该绑定。
- **本地补丁：** `fix-eis-device-region.patch` 让后端下发 `ei_device.region`。上游从不下发，而这是 libei 客户端唯一能确定"本机屏幕"尺寸的信息：缺失时 Deskflow 保持 1×1 的屏幕模型，每次捕获激活的光标位置都被压到 `(0, 0)`，该点先满足上边缘判定，于是下边缘与右边缘成为死代码 - 客户端配在本机下方或右侧时指针切不过去，配在上方反而能用。补丁在 `ConnectToEIS` 时取一次输出布局并集，在创建每个 device 的回调里、`ei_device.done` 之前下发；顺序是硬要求，libei 只在构建 device 时读取 region，协议中没有 region 事件，晚发等同于没发。
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

### `ltrace` 的 `demangle` 测试在 GCC 16 下编译失败

- **位置：** `modules/home/defaults/packages.nix` 的 `ltrace` 覆盖。
- **影响：** nixpkgs 输入更新到 `nixos-26.11pre1082427.b4fd65b198c5` 后，工具链默认编译器升到 GCC 16.2.0。`testsuite/ltrace.minor/demangle-lib.cpp` 里的 `volatile int Fv_Vi(void)` 触发 GCC 16 新增的 `-Wvolatile` 警告，而 ltrace 的测试框架（`testsuite/lib/ltrace.exp` 中 `if { $result != "" ... }`）只判断编译器输出是否为空 - 任何输出（含 warning）都算 "compile failed"。测试程序因此未生成，`make check` 报 15 个 unexpected failures 并以退出码 2 结束。
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

- **位置：** `flake.nix` 的 `nixpkgs.overlays`，由 `modules/home/defaults/theme.nix`（安装 qt6ct 本体）、`modules/desktop/dms-with-niri/ui.nix`（`platformTheme.name` 与 `QT_QPA_PLATFORMTHEME_QT6`）和 `modules/optional/wine.nix`（`QT_PLUGIN_PATH`）共同使用。
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

  注意 `GetDesktopEnvironment()` 会读 `DESKTOP_SESSION`、`KDE_FULL_SESSION`、`KDE_SESSION_VERSION` 与 `GNOME_DESKTOP_SESSION_ID`，只改 `XDG_CURRENT_DESKTOP` 复现不出 KDE 分支——必须像上面那样先清掉它们。确认包装器已注入参数：

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

- **位置：** `flake.nix` 的 `linuxPackages_latest` 覆盖（内嵌补丁），以及 `hosts/mooling-laptop/default.nix` 的驱动配置。
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

- **位置：** `modules/desktop/dms-with-niri/xdg-portals.nix` 的 `xdg.portal.config` 与 `xdg.dataFile`。
- **影响：** DMS 会通过 dconf 写入 `org.gnome.desktop.interface color-scheme`，但 `xdg-desktop-portal 1.22` 可同时加载 GTK、GNOME 和 KDE 的 `Settings` 后端，导致门户向 QQ、Telegram、Zen 等应用报告与 DMS 相反的深浅色状态。
- **当前处理：** 在通用和 Niri 门户配置中将 `org.freedesktop.impl.portal.Settings` 固定为 GTK；同时从用户优先级的 GNOME/KDE portal 定义中去除该接口，仅保留 GTK 作为 Settings 提供方。原定义直接由当前 Nix 包读取，避免手工复制后随上游接口列表漂移。
- **上游：** xdg-desktop-portal [#2033](https://github.com/flatpak/xdg-desktop-portal/issues/2033)，修复 PR [#2048](https://github.com/flatpak/xdg-desktop-portal/pull/2048)；相关 DMS/Niri 报告 [#2140](https://github.com/AvengeMedia/DankMaterialShell/issues/2140)。
- **移除条件：** 使用的 `xdg-desktop-portal` 已包含 #2048 的等效修复，且移除两个用户 portal 定义后，DMS 深色时门户仍返回 `uint32 1`、浅色时返回 `uint32 2`，并且应用能动态收到切换通知。
- **复查方法：** 临时移除两个 `xdg.dataFile` 条目后，重建并重启 `xdg-desktop-portal`；用下列命令分别在 DMS 的深色和浅色模式下检查：

  ```fish
  gdbus call --session --dest org.freedesktop.portal.Desktop --object-path /org/freedesktop/portal/desktop --method org.freedesktop.portal.Settings.Read org.freedesktop.appearance color-scheme
  ```

### Fcitx5 Plasma 候选窗的 DMS 深浅色同步

- **位置：** `modules/desktop/dms-with-niri/fcitx-theme-sync.nix` 的 `fcitx5-dms-theme-sync` 用户 service 与 path unit。
- **影响：** Fcitx5 的实验性 `plasma` Classic UI 主题跟随 Plasma Shell 的 SVG 主题，而不读取 DMS 发布的门户深浅色或强调色；在 Niri 会话中它会回退到白色 `breeze-light` 和固定蓝色高亮。服务监听 DMS 写入的 `DankMatugen.colors`，根据同一文件的窗口背景亮度选择 `breeze-light` 或 `breeze-dark` 色表来组装私有主题；资源同时写入 Plasma 和 Fcitx 生成器的标准查找路径，并从该次色表读取选择前景/背景色来重着色候选项，最后调用 Fcitx `Controller1.Restart`。该接口与系统托盘的“重启”相同，会重新创建缓存 `NormalColor` 的 Classic UI，同时保留原实例的插件环境与输入法列表。这样不会因 DMS 先写色表、后更新 dconf 而将浅色调色板配上深色背景，也不必手动重启输入法。
- **范围：** 只使用已由 `fcitx5-configtool` 引入的 `libplasma`、`kconfig` 与 `kcolorscheme` 库，以及只用于重着色候选项 PNG 的 ImageMagick；不会安装或启动 Plasma Shell、KWin 或其他 KDE 桌面服务。同步 service 不直接由 `graphical-session.target` 启动，而仅由 path unit 在 DMS 写入色表后触发；DMS 本身必须在该 target 之后启动，若同时把同步 service 作为 target 成员并声明 `After=dms.service`，systemd 会形成排序循环并丢弃 DMS 的启动任务。
- **移除条件：** DMS 提供原生 Fcitx5 模板，或 Fcitx5 的 Plasma 主题能直接根据 `org.freedesktop.appearance color-scheme` 选择浅/深资源。
- **复查方法：** 暂停 path unit 后切换 DMS 深浅色，确认候选窗不再变化；恢复后运行 `systemctl --user start fcitx5-dms-theme-sync.service`，检查 `~/.local/share/fcitx5/themes/dms-plasma/panel.png` 的背景随模式切换。

### Wine 的 PipeWire 与 WoW64 兼容层

- **位置：** `modules/system/packages.nix` 的 `pulseaudio`；`modules/optional/wine.nix` 的 `wine64-symlink`、`WINEDLLOVERRIDES` 与 `QT_PLUGIN_PATH`；`modules/home/defaults/wine.nix` 和生成的 Fish 配置中的同一变量。
- **影响：** 禁用 `winealsa.drv`，改由 PipeWire 的 PulseAudio 兼容层处理音频，以避免 `winecfg` 枚举音频设备时卡死；同时伪造 `wine64`，满足 WoW64 模式下的 `winetricks` 查找。
- **相关提交：** `89f35ae`（`fix: add pulseaudio and disable winealsa to prevent winecfg audio tab freeze`）；`6201ec7`（`fix: add wine64 symlink for winetricks WoW64 compatibility`）。
- **移除条件：** 当前 Wine 在 PipeWire 下运行 `winecfg` 不再卡死，且 WoW64 的 `winetricks` 可直接找到实际的 `wine64` 可执行文件。
- **复查方法：** 在测试环境中移除上述覆盖，运行 `winecfg` 并执行实际使用的 WoW64 `winetricks` 流程；两者通过后再删除兼容层。

### Apollo 串流模块被永久移除

所有串流相关的 flake 输入、模块代码均已被删除，用户不再使用。

相关提交： `bd9bd97`（`fix!: remove apollo/sunshine streaming service completely`）

### Home Manager 冲突备份后缀

- **位置：** `flake.nix` 的 `home-manager.backupFileExtension = "backup"`。
- **影响：** 激活时会将与 Home Manager 目标文件冲突的既有文件重命名为 `.backup`；原用于处理由 DMS/Niri 运行时管理的 `config.kdl` 冲突。
- **相关提交：** `64177f6`（`fix: add home-manager.backupFileExtension to resolve config.kdl conflicts`）；`a383c84`（`fix!: stop declaratively managing DMS and NvChad runtime config`）移除了最初的配置冲突来源。运行时 Niri/DMS 配置已不再由 Home Manager 声明式管理，因此需重新确认该后缀是否仍有必要。
- **移除条件：** 不存在其他需要保留的 Home Manager 目标文件冲突，且移除该选项后的 Home Manager 激活成功。
- **复查方法：** 临时移除该选项后执行常规 `nixos-rebuild switch`；若激活报出文件冲突，先确认该目标文件是否应由 Home Manager 接管，再决定是否保留该后缀。
