# NixOS Configuration

基于 [DankMaterialShell](https://danklinux.com/) 的 NixOS + niri 桌面配置。

## 结构

> 该部分信息存在滞后性，当前版本：2026-06-13 13:31

```
├── AGENTS.md                     # Agent 工作说明和项目约定
├── assets/                       # 壁纸、头像等静态资源
├── cache                         # 本地缓存文件
├── deploy.sh                     # 新机器交互式部署脚本
├── flake.lock
├── flake.nix                     # Flake 入口（username/hostname let 绑定在此）
├── hosts/<hostname>/             # 机器专属
│   ├── default.nix               # imports + boot + hostname + stateVersion
│   ├── gpu.nix                   # GPU 驱动配置
│   ├── hardware-configuration.nix # 自动生成硬件配置
│   ├── streaming-devices.nix     # 串流虚拟设备
│   ├── streaming-display.nix     # 串流显示相关 Home Manager 配置
│   └── streaming.nix             # 串流系统服务配置
├── modules/
│   ├── home/                     # Home Manager 模块（跨机器复用）
│   │   ├── backup.nix            # 运行时配置缺失时自动恢复快照
│   │   ├── default.nix           # 入口和模块 imports
│   │   ├── desktop.nix           # DMS、终端、壁纸/头像
│   │   ├── git.nix               # Git 用户配置
│   │   ├── nvchad.nix            # nix4nvchad 包装和依赖
│   │   ├── packages.nix          # 用户包
│   │   ├── ssh.nix               # SSH 客户端配置
│   │   └── theme.nix             # Qt、字体、xdg.portal
│   └── system/                   # 系统模块（跨机器复用）
│       ├── config.nix            # my.username 选项
│       ├── desktop.nix           # dms-greeter + niri + Firefox
│       ├── fonts.nix             # 系统级字体
│       ├── i18n.nix              # 中文语言、fcitx5 输入法
│       ├── networking.nix        # NetworkManager、Clash Verge
│       ├── nix.nix               # nix 调优 + 自动 GC
│       ├── packages.nix          # 系统级包
│       ├── services.nix          # 蓝牙、打印、PipeWire、SSH
│       ├── users.nix             # 用户 + sudo
│       └── virtualisation.nix    # 虚拟化配置
├── README.md
├── reasonix.toml                 # Reasonix 配置
├── scripts/                      # 辅助脚本
│   ├── apollo-upnp.sh            # Apollo UPnP 辅助脚本
│   └── backup.sh                 # 分布式备份/恢复脚本总入口
└── user_profiles/<username>/      # 用户运行时配置快照
    └── desktop-config/           # DMS/Niri 可变配置备份
        ├── apply.sh              # 从快照恢复运行时配置
        ├── dms/                  # DMS 可变配置快照
        │   ├── plugins/          # DMS 插件元数据快照
        │   └── settings.json     # DMS 主设置快照
        ├── niri/                 # Niri 可变配置快照
        │   ├── config.kdl        # Niri 主配置快照
        │   └── dms/              # DMS 生成的 Niri KDL 快照
        └── snapshot.sh           # 捕获当前运行时配置到仓库
```

## 自定义用户名

编辑 `flake.nix`，修改 `let username` 一行即可：

```nix
outputs = inputs@{ nixpkgs, home-manager, ... }:
  let
    username = "mooling";  # ← 改为你的用户名
  in
```

所有系统模块和 Home Manager 配置均自动引用此变量，无需其他修改。

## 新机器部署

```fish
# 1. 安装 NixOS 后，克隆配置仓库
git clone git@github.com:Mooling0602/dms-starter.git ~/nixos-config

# 2. 运行部署脚本（交互式）
cd ~/nixos-config && ./deploy.sh

# 3. 设置密码
sudo passwd <username>

# 4. 重建
sudo nixos-rebuild switch --flake ~/nixos-config#<hostname>
```

## 已部署机器的日常使用

```fish
cd ~/nixos-config
# 修改配置 → git commit → 重建 → git push
sudo nixos-rebuild switch --flake ~/nixos-config#mooling-laptop
```

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

- **`nix.settings.auto-optimise-store = true`** — 每次构建时自动硬链接优化
- **`nix.gc.automatic = true` + `--delete-older-than 7d`** — 每周自动垃圾回收
- **`boot.loader.systemd-boot.configurationLimit = 10`** — 最多保留 10 个 boot 启动项

### 手动清理旧世代（只保留最新 N 个）

```bash
sudo nix profile wipe-history --profile /nix/var/nix/profiles/system --older-than 1d
```

### 查看当前状态

```bash
nix profile history --profile /nix/var/nix/profiles/system  # 系统世代历史
sudo bootctl list                                             # 当前 boot 启动项
df -h / /boot                                                 # 磁盘使用
du -sh /nix/store                                             # nix store 大小
```

## 配置边界

- DMS/Niri 运行配置不由 Home Manager 挂载；`~/.config/niri/` 和 DMS 自身配置文件由应用自己写入。
- DMS/Niri 可变配置快照保存在 `user_profiles/mooling/desktop-config/`，仅用于备份和审查。
- NvChad Lua 配置来自独立仓库 `github:Mooling0602/NvCfg`，本仓库只保留 `nix4nvchad` 包装和运行时依赖。

## 人脸认证

已启用 [Howdy](https://github.com/boltgolt/howdy) 的全局 PAM 认证，适用于 DMS Greeter 登录、`sudo`、本机锁屏和 SSH 等使用 PAM 的服务。人脸认证成功可直接放行，识别失败时仍会要求输入密码。

```fish
# 首次录入；为不同光照和角度添加多张样本
sudo howdy add mooling

# 查看、删除已录入样本
sudo howdy list
sudo howdy remove mooling
```

- 摄像头使用稳定路径 `/dev/v4l/by-id/usb-Sonix_Technology_Co.__Ltd._BisonCam_NB_Pro-video-index0`。
- SSH 认证时，Howdy 扫描的是本机摄像头，不能读取 SSH 客户端的摄像头。
- 这台设备是普通 RGB 摄像头；Howdy 不提供可靠活体检测，可能被照片欺骗，不应将其视为密码的安全替代品。

## 运行时配置备份

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
