# NixOS Configuration

基于 [DankMaterialShell](https://danklinux.com/) 的 NixOS + niri 桌面配置。

## 结构

```
├── flake.nix                  # Flake 入口
├── flake.lock
├── hosts/mooling-laptop/
│   ├── default.nix            # 机器特定配置
│   ├── hardware-configuration.nix
│   └── home.nix               # Home Manager 配置
├── modules/system/
│   ├── desktop.nix            # DMS greeter、niri、Firefox
│   ├── fonts.nix              # 系统级字体
│   ├── gpu.nix                # NVIDIA 驱动 + Prime Offload
│   ├── i18n.nix               # 中文语言、fcitx5 输入法
│   ├── networking.nix         # NetworkManager、Clash Verge
│   ├── packages.nix           # 系统级包
│   ├── services.nix           # 打印、PipeWire、SSH、蓝牙
│   └── users.nix              # 用户 mooling、sudo
└── assets/
    └── avatar.jpg             # 用户头像
```

## 使用

```fish
sudo nixos-rebuild switch --flake ~/nixos-config#mooling-laptop
```

## 参考

- [DankMaterialShell 文档](https://danklinux.com/docs/)
- [niri 文档](https://github.com/YaLTeR/niri)
- [NixOS Wiki](https://nixos.wiki/)
