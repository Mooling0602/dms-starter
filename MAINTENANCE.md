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
  xwayland-satellite = inputs.niri.packages.${final.system}.xwayland-satellite-unstable;
  ```

  然后运行：

  ```fish
  nix flake update niri
  nix build .#nixosConfigurations.mooling-laptop.config.system.build.toplevel --no-link
  ```

  构建成功后，在受分数缩放影响的 XWayland 应用中验证弹出窗口不再出现零尺寸锚点。

## 临时构建绕过

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

### `face-recognition-models` 的 Python 3.14 `pkg_resources` 兼容性

- **位置：** `flake.nix` 的 `pythonPackagesExtensions` 覆盖。
- **影响：** `face-recognition-models 0.3.0` 使用 Python 3.14 已移除的 `pkg_resources.resource_filename` 定位随包安装的模型文件，导致导入失败，并阻断 Howdy 的系统闭包构建。
- **当前处理：** 在构建时将该调用替换为标准库 `importlib.resources.files`，并将模型资源路径转换为字符串；保留 `pythonImportsCheck` 以及依赖它的 `face-recognition` 上游测试。
- **相关提交：** `3ad1630`（`feat: enable Howdy face authentication`）。
- **上游：** https://github.com/ageitgey/face_recognition_models/blob/master/face_recognition_models/__init__.py ，Nixpkgs 包定义： https://github.com/NixOS/nixpkgs/blob/nixos-unstable/pkgs/development/python-modules/face-recognition/models.nix
- **移除条件：** 上游或 Nixpkgs 已移除 `pkg_resources` 用法，且不使用本覆盖时 Howdy 系统闭包可成功构建。
- **复查方法：** 临时删除该覆盖后运行：

  ```fish
  nix build .#nixosConfigurations.mooling-laptop.config.system.build.toplevel --no-link
  ```

  构建成功后永久删除覆盖，再重复同一命令确认。

### 最小特性 GDAL 的 Zarr 分片缓存测试

- **位置：** `flake.nix` 的 `gdal` 覆盖；通过其 `override { useMinimalFeatures = true; }` 传播至顶层 `gdalMinimal` 及 VTK 自行创建的最小特性 GDAL。
- **影响：** `gdal-minimal 3.13.1` 未启用 `netCDF` 驱动，但 `test_zarr_read_simple_sharding` 仍断言由该驱动写入的 `zarr.json.gmac` 缓存文件存在，导致 VTK 及其下游系统闭包构建失败。
- **当前处理：** 仅当 `pname` 为 `gdal-minimal` 时跳过该不满足前置驱动条件的测试，其余 GDAL 测试保持执行；等价于 GDAL 上游 PR #14940 添加的 `@pytest.mark.require_driver("netCDF")` 标记。
- **相关提交：** `3ad1630`（`feat: enable Howdy face authentication`）。
- **上游：** https://github.com/OSGeo/gdal/pull/14940 ，Nixpkgs 问题： https://github.com/NixOS/nixpkgs/issues/540609
- **移除条件：** PR #14940 或等效修复已合入 Nixpkgs，且更新后的最小特性 GDAL 不使用本覆盖可成功构建。
- **复查方法：** 更新 `nixpkgs` 输入后临时删除该覆盖并运行：

  ```fish
  nix build .#nixosConfigurations.mooling-laptop.config.system.build.toplevel --no-link --print-build-logs
  ```

   成功后永久删除覆盖，再重复同一命令确认。

### `pdal` 与 GDAL 3.13 的元数据 API 兼容性

- **位置：** `flake.nix` 的 `pdal` 覆盖；通过其 `override { }` 传播至 VTK 自行创建的 PDAL。
- **影响：** `pdal 2.9.3` 将 GDAL 3.13 的只读 `CSLConstList` 元数据列表赋值给可写 `char **`，导致编译失败，并阻断 VTK、OpenCV 及 Howdy 系统闭包构建。
- **当前处理：** 采用 PDAL 上游提交 `eb7220a` 的最小替换：使用 `CSLConstList` 保存元数据，并用 `CSLCount` 遍历列表。
- **相关提交：** `3ad1630`（`feat: enable Howdy face authentication`）。
- **上游：** https://github.com/PDAL/PDAL/commit/eb7220a2447c5b3d208d7ef0a76c61a17a5b21da ，Nixpkgs 包定义： https://github.com/NixOS/nixpkgs/blob/nixos-unstable/pkgs/by-name/pd/pdal/package.nix
- **移除条件：** Nixpkgs 的 PDAL 已包含该提交或等效 GDAL 3.13 兼容修复，且移除覆盖后系统闭包可成功构建。
- **复查方法：** 更新 `nixpkgs` 输入后临时删除该覆盖并运行：

  ```fish
  nix build .#nixosConfigurations.mooling-laptop.config.system.build.toplevel --no-link --print-build-logs
  ```

  构建成功后永久删除覆盖，再重复同一命令确认。

### `vtk` 与 GDAL 3.13 的元数据 API 兼容性

- **位置：** `flake.nix` 的 `vtk` 覆盖。
- **影响：** `vtk 9.5.2` 将 GDAL 3.13 的只读 `CSLConstList` 元数据列表赋值给可写 `char **`，在 `vtkGDALRasterReader` 中编译失败，并阻断 OpenCV、Howdy 系统闭包构建。
- **当前处理：** 采用 VTK 上游提交 `2395603` 的完整四处条件编译修复，针对 GDAL 3.13 及更高版本使用 `const char* const*`，保留旧版 GDAL 的原有类型。
- **相关提交：** `3ad1630`（`feat: enable Howdy face authentication`）。
- **上游：** https://github.com/Kitware/VTK/commit/2395603fdddc40c29efc64c632ae98225ca2a58e ，Nixpkgs 包定义： https://github.com/NixOS/nixpkgs/blob/nixos-unstable/pkgs/development/libraries/vtk/generic.nix
- **移除条件：** Nixpkgs 的 VTK 已包含该提交或等效 GDAL 3.13 兼容修复，且移除覆盖后系统闭包可成功构建。
- **复查方法：** 更新 `nixpkgs` 输入后临时删除该覆盖并运行：

  ```fish
  nix build .#nixosConfigurations.mooling-laptop.config.system.build.toplevel --no-link --print-build-logs
  ```

  构建成功后永久删除覆盖，再重复同一命令确认。

## 外部功能补丁

### `qt6ct-kde` 的 KColorScheme 支持

- **位置：** `modules/home/theme.nix` 中的 `qt6Packages.qt6ct.overrideAttrs`。
- **目的：** 为 `qt6ct` 加入 `kconfig`、`kcolorscheme`、`kiconthemes` 构建依赖，并应用 Arch AUR `qt6ct-kde` 的 shenanigans 补丁，使 Qt 配色方案能够使用 KDE 的 `KColorScheme` 支持。
- **相关提交：** `d4c18f6`（`fix: use qt6ct-kde patch instead of vanilla qt6ct`）。
- **补丁来源：** https://aur.archlinux.org/cgit/aur.git/plain/qt6ct-shenanigans.patch?h=qt6ct-kde
- **移除条件：** Nixpkgs 的 `qt6ct` 包已原生包含等效补丁和 KDE 依赖，或上游 `qt6ct` 已正式提供等效功能；删除前需确认 DMS 浅色和深色主题切换后的 Qt 应用配色正确。
- **复查方法：** 更新输入后检查 Nixpkgs 包定义：

  ```fish
  nix edit nixpkgs#qt6Packages.qt6ct
  ```

  若功能已上游化，删除此 `overrideAttrs`，构建系统后在图形会话中切换 DMS 主题验证。

## 配置例外与兼容层

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
