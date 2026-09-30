# NixOS Configuration: dms-starter

A template with desktop modification sets.

模块化的 NixOS Flake 系统配置，支持多用户、多设备和可选的桌面模块功能进行自由组合。

## 支持的桌面模块

- [DankMaterialShell](https://danklinux.com/) 已完成，持续维护
- [KDE Plasma](https://wiki.nixos.cn/wiki/KDE) 工作中，尚不推荐使用

## 自定义用户名和主机名

编辑 `flake.nix`，修改 `let in` 块内的相关变量即可：

```nix
outputs = inputs@{ nixpkgs, home-manager, ... }:
  let
    username = "user";  # <- 改为你的用户名
    hostname = "nixos";    # <- 改为你的主机名
  in
```

所有系统模块和 Home Manager 配置均自动引用这两个变量，目录名需与之一致：

- `hosts/<hostname>/` - 机器专属配置
- `modules/home/<username>/` - 个人模块，可从 `modules/home/user/` 复制模板
- `assets/<username>/` - 个人资源（头像等）
- `user_profiles/<username>/` - 运行时配置快照（见「运行时配置备份」）

## 新机器部署

```fish
# 1. 安装 NixOS 后，克隆配置仓库
git clone git@github.com:Mooling0602/dms-starter.git ~/nixos-config

# 2. 运行交互式部署脚本即可
cd ~/nixos-config && ./deploy.sh

# 3. 你还可以自行做其他修改，完善你 fork 的配置，也欢迎从此仓库内持续引入各种修复内容
```

## 已部署机器的日常使用

```fish
cd ~/nixos-config
# 修改配置 -> git commit -> 重建 -> git push
nixos-rebuild-nom switch --flake ~/nixos-config#mooling-laptop
```

`nixos-rebuild-nom` 会通过 `nix-output-monitor`（`nom`）展示构建进度，并保留原始重建命令的退出状态。

## 系统垃圾清理

NixOS 每次重建都会产生新的世代（generation）和 boot 启动项，积累多了会占用大量空间。

### 快速清理（日常）

```bash
# 删除 7 天前的旧系统世代（同时清理 boot 启动项和旧内核）
sudo nix profile wipe-history --older-than 7d --profile /nix/var/nix/profiles/system

# 系统级垃圾回收（删除未引用的 /nix/store 路径）
sudo nix-collect-garbage --delete-old

# 用户级垃圾回收（清理 home-manager 和用户 profile）
nix-collect-garbage --delete-old

# 优化 /nix/store（用硬链接去重，节省额外空间）
sudo nix-store --optimise
```

### 预留的世代限制

配置中已启用以下自动策略（见 `modules/system/nix.nix` 和 `hosts/*/default.nix`）：

- **`nix.settings.auto-optimise-store = true`** - 每次构建时自动硬链接优化
- **`nix.gc.automatic = true` + `--delete-older-than 1d`** - 每天自动垃圾回收
- **`boot.loader.systemd-boot.configurationLimit = 10`** - 最多保留 10 个 boot 启动项

### 手动清理旧世代（只保留最新 N 个）

```bash
sudo nix profile wipe-history --profile /nix/var/nix/profiles/system --older-than 7d
```

### 查看当前状态

```bash
nix profile history --profile /nix/var/nix/profiles/system    # 系统世代历史
sudo bootctl list                                             # 当前 boot 启动项
df -h / /boot                                                 # 磁盘使用
du -sh /nix/store                                             # nix store 大小
```

## 配置边界

- DMS/Niri 运行配置不由 Home Manager 挂载；`~/.config/niri/` 和 DMS 自身配置文件由应用自己写入。
- DMS/Niri 可变配置快照保存在 `user_profiles/mooling/desktop-config/`，仅用于备份和审查。
- NvChad Lua 配置来自独立仓库 `github:Mooling0602/NvCfg`，本仓库只保留 `nix4nvchad` 包装和运行时依赖。

## 人脸认证

已启用 [Howdy](https://github.com/boltgolt/howdy) 的 PAM 认证，适用于 `sudo`、本机锁屏和 SSH 等使用 PAM 的服务。DMS Greeter 及其复用的 `login` 认证栈排除 Howdy，必须输入密码，以便自动解锁 GNOME Keyring。其余服务中，人脸认证成功可直接放行，识别失败时仍会要求输入密码。

认证开始时会显示 Howdy 的检测提示；若画面太暗或识别超时，则输入密码继续。录入多个光照和角度的样本可提高识别率。

需要设备有摄像头，后续将考虑默认禁用此功能，你可以先自行本地修改。

```fish
# 首次录入；为不同光照和角度添加多张样本
sudo howdy add mooling

# 查看、删除已录入样本
sudo howdy list
sudo howdy remove mooling
```

- SSH 认证时，Howdy 扫描的是本机摄像头，不能读取 SSH 客户端的摄像头。
- 对于普通的 RGB 摄像头，Howdy 不提供可靠活体检测，可能被照片欺骗，不应将其视为密码的安全替代品。

## 运行时配置备份

> 主要是 mooling 个人使用，你可以根据需要复制模板或自行编写模块。

```fish
# 捕获当前 DMS/Niri 可变配置到仓库快照
./scripts/backup.sh snapshot mooling

# 从仓库快照恢复；如果已有相关配置，会二次确认（N/y）
./scripts/backup.sh apply mooling

# 跳过二次确认，强制恢复
./scripts/backup.sh apply --force mooling
```

- `snapshot.sh` 直接覆盖仓库快照中有变化的文件，不做二次确认。
- `apply.sh` 默认在已有 DMS/Niri 配置时要求二次确认；`-f` 或 `--force` 可跳过确认。
- `modules/home/backup.nix` 在 Home Manager 激活时检查用户名；若用户名匹配且 DMS 或 Niri 配置缺失，会自动执行 `apply-missing` 并跳过二次确认。
- 当前 DMS 快照只保留 `settings.json` 和插件 `.meta`，不提交 `plugin_settings.json`、浏览器 CSS、插件仓库缓存等易变或可能含设备标识的文件。

## 参考

- [DankMaterialShell 文档](https://danklinux.com/docs/)
- [niri 文档](https://github.com/YaLTeR/niri)
- [NixOS Wiki](https://nixos.wiki/)
