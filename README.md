# NixOS Configuration: dms-starter

A template with desktop modification sets.

模块化的 NixOS Flake 系统配置，支持多用户、多设备和可选的桌面模块功能进行自由组合。

## 支持的桌面模块

- [DankMaterialShell](https://danklinux.com/) 已完成，持续维护
- [KDE Plasma](https://wiki.nixos.cn/wiki/KDE) 工作中，尚不推荐使用

## 设备身份：用户名与主机名

`flake.nix` 只枚举 `hosts/` 下的主机目录，**不承载任何具体设备信息**。每台设备的身份写在自己的主机目录里：

```nix
# hosts/<hostname>/default.nix
{ config, hostname, ... }:

let
  # 本机使用的桌面模块名，对应 ./desktop/<desktop>/。
  # 必须是 let 绑定：imports 求值早于 config，写成 config.my.desktop 会无限递归。
  desktop = "dms-with-niri";
in

{
  # ── 设备身份（本机唯一改动点）────────────────────────────────
  my.username = "user";
  my.hostname = hostname;   # 目录名由 flake.nix 注入
  my.desktop = desktop;
  # ───────────────────────────────────────────────────────────

  imports = [
    /* ... */
    ./desktop/${desktop}/default.nix
  ];
  networking.hostName = config.my.hostname;
}
```

多个设备共用本仓库时，各自只改自己 `hosts/<hostname>/default.nix` 顶部的几行，不会互相冲突或覆盖。

约定的目录名需与身份一致：

- `hosts/<hostname>/` - 机器专属配置
- `modules/home/<username>/` - 个人模块，按需自行编写；缺失的文件由 `utils/optional_import.nix` 跳过并给出求值警告（旧版曾提供 `modules/home/user/` 模板，已于 `a3328c3` 移除）
- `assets/<username>/` - 个人资源（头像等）
- `user_profiles/<username>/` - 运行时配置快照（见「运行时配置备份」）

`modules/home/default.nix` 只负责**桌面无关**的用户配置：从 `modules/home/<username>/` 导入 `default.nix`、`git.nix`、`packages.nix`、`avatar.nix`（均非必需），加上 `hosts/<hostname>/users/<username>.nix` 与 `modules/home/defaults/` 下的通用模块。可按需在 `modules/home/<username>/` 中引用的共享模块放在 `modules/optional/`（如 `screen-recorder.nix`、`kde-connect.nix`）。

桌面专属的 Home Manager 配置**不在这里**：由当前桌面层通过 `home-manager.sharedModules` 挂载（见下节），因此未选中的桌面不会污染用户环境。

新增设备只需新建一个 `hosts/<hostname>/default.nix`，**无需改动 `flake.nix`**（注意 git flake 只打包已跟踪文件，新目录要先 `git add`）。

## 桌面模块

桌面相关配置分三层，新增或切换桌面时按此对应：

```text
hosts/<hostname>/default.nix          # let desktop = "dms-with-niri"; 决定导入哪个桌面
└── hosts/<hostname>/desktop/<name>/  # 主机专属的桌面追加配置
    └── modules/desktop/<name>/       # 桌面实现（系统层 + Home Manager 层）
```

- **切换桌面**：只改 `hosts/<hostname>/default.nix` 顶部的 `let desktop = "..."`，它同时决定 `my.desktop` 的值与 `imports` 的路径。
- **一致性校验（由实现模块直接断言）**：`modules/desktop/<name>/system.nix` 断言 `my.desktop` 等于 `baseNameOf ./.`，即「声明要用的桌面」必须等于「本实现实际所在的目录名」。桌面名无需手工维护，重命名实现目录后断言自动跟随；声明与实际不符（例如声明 `kde-plasma` 却导入了 `dms-with-niri` 的实现）会在求值阶段报错。
- **兜底校验**：`modules/system/config.nix` 断言至少有一个实现被加载。若 `hosts/<hostname>/desktop/<name>/default.nix` 忘了导入 `modules/desktop/<name>/system.nix`（或路径写错被 `optionalImports` 静默跳过），此时实现模块不存在、它自己的断言也不会执行，只能由这条兜底。

### 桌面专属的 Home Manager 配置

桌面实现层（`modules/desktop/<name>/system.nix`）通过 `home-manager.sharedModules` 把自己专属的 Home Manager 模块挂进用户环境，例如 `dms-with-niri` 会挂上 `./default.nix`（`dms-with-niri` 的 HM 层）以及上游 `inputs.dms` / `inputs.danksearch` / `inputs.dankcalendar` 的模块。

**这是刻意的设计约束**：`flake.nix` 的 `home-manager.users.<name>.imports` 只放桌面无关的模块（`./modules/home`、`nvchad`、`codex-desktop`）。任何 DMS 生态的模块若写在那里，切换桌面后仍会生效——曾经因此出现过「切到 KDE 后 `dms.service`、`dsearch.service`、`fcitx5-dms-theme-sync` 依旧存在」的问题。同理，桌面专属的 `home.activation` 步骤（如 `restoreDesktopConfig`）也必须放在桌面层内。

系统层模块通过 `specialArgs` 拿到 `inputs`，因此可以直接引用自己桌面所需的 input，无需在 `flake.nix` 里为它额外加 overlay 或 `extraSpecialArgs`。

> `imports` 的求值早于 `config`，因此**不能**写成 `imports = [ ./desktop/${config.my.desktop}/... ]`（会无限递归）；必须使用 `let` 绑定的局部变量。

## 新机器部署

```fish
# 1. 安装 NixOS 后，克隆配置仓库
git clone git@github.com:Mooling0602/dms-starter.git ~/nixos-config

# 2. 运行交互式部署脚本即可
cd ~/nixos-config && ./deploy.sh

# 3. 你还可以自行做其他修改，完善你 fork 的配置，也欢迎从此仓库内持续引入各种修复内容
```

`deploy.sh` 会写出 `hosts/<hostname>/default.nix` 并填好 `my.username` / `my.hostname`，全程不改 `flake.nix`。

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
- **`nix.gc.automatic = true`，`dates = "weekly"` + `--delete-older-than 1d`** - 每周自动垃圾回收，删除 1 天前的世代
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
- 终端分两层：`modules/home/defaults/terminal.nix` 定义终端程序、字体与桌面无关的偏好；跟随桌面会话的配色放在各桌面模块内（如 `modules/desktop/dms-with-niri/terminal.nix` 引用 DMS matugen 生成的配色文件），由 Home Manager 自动合并。

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
- 两者位于各用户的 `user_profiles/<username>/desktop-config/` 下，`scripts/backup.sh` 负责按用户分发调用。
- `modules/desktop/dms-with-niri/backup.nix` 在 Home Manager 激活时检查用户名；若用户名匹配且 DMS 或 Niri 配置缺失，会自动执行 `apply-missing` 并跳过二次确认。它随 DMS 桌面层加载，切到其他桌面时该激活步骤不会执行。
- 当前 DMS 快照只保留 `settings.json` 和插件 `.meta`，不提交 `plugin_settings.json`、浏览器 CSS、插件仓库缓存等易变或可能含设备标识的文件。

## 参考

- [DankMaterialShell 文档](https://danklinux.com/docs/)
- [niri 文档](https://github.com/YaLTeR/niri)
- [NixOS Wiki](https://nixos.wiki/)
