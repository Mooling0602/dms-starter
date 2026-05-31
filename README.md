# NixOS Configuration

基于 [DankMaterialShell](https://danklinux.com/) 的 NixOS + niri 桌面配置。

## 结构

> 该部分信息存在滞后性，当前版本：2026-05-31 14:41

```
├── flake.nix                     # Flake 入口（username let 绑定在此）
├── flake.lock
├── hosts/<hostname>/             # 机器专属
│   ├── default.nix               # imports + boot + hostname + stateVersion
│   ├── gpu.nix                   # GPU 驱动配置
│   └── hardware-configuration.nix # 自动生成
├── modules/
│   ├── home/                     # Home Manager 模块（跨机器复用）
│   │   ├── default.nix           # 入口
│   │   ├── packages.nix          # 用户包
│   │   ├── theme.nix             # Qt、字体、xdg.portal
│   │   ├── desktop.nix           # DMS、niri、alacritty、壁纸/头像
│   │   └── git.nix               # Git 用户配置
│   └── system/                   # 系统模块（跨机器复用）
│       ├── config.nix            # my.username 选项
│       ├── desktop.nix           # dms-greeter + niri + Firefox
│       ├── fonts.nix             # 系统级字体
│       ├── i18n.nix              # 中文语言、fcitx5 输入法
│       ├── networking.nix        # NetworkManager、Clash Verge
│       ├── nix.nix               # nix 调优 + 自动 GC
│       ├── packages.nix          # 系统级包
│       ├── services.nix          # 蓝牙、打印、PipeWire、SSH
│       └── users.nix             # 用户 + sudo
└── niri/                         # Niri KDL 配置（DMS 可写）
    ├── config.kdl
    └── dms/
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

## 参考

- [DankMaterialShell 文档](https://danklinux.com/docs/)
- [niri 文档](https://github.com/YaLTeR/niri)
- [NixOS Wiki](https://nixos.wiki/)
