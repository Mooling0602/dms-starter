#!/usr/bin/env bash
set -euo pipefail

REPO_ROOT="$(cd "$(dirname "$0")/.." && pwd)"

echo "=== NixOS 新机器部署 ==="
echo ""

read -rp "主机名 (hostname): " HOSTNAME
read -rp "用户名: " USERNAME
read -rp "Git 用户名: " GIT_NAME
read -rp "Git 邮箱: " GIT_EMAIL

echo ""
echo "--- 即将进行的操作 ---"
echo "主机名:   $HOSTNAME"
echo "用户名:   $USERNAME"
echo "Git:      $GIT_NAME <$GIT_EMAIL>"
echo ""
read -rp "确认? [y/N] " CONFIRM
[[ "$CONFIRM" =~ ^[Yy]$ ]] || { echo "已取消"; exit 0; }

cd "$REPO_ROOT"

# 1. 创建机器目录
echo "==> 创建 hosts/$HOSTNAME/"
mkdir -p "hosts/$HOSTNAME"

# 2. 生成硬件配置
echo "==> 生成 hardware-configuration.nix"
sudo nixos-generate-config --root / --dir "hosts/$HOSTNAME"

# 3. 写入 default.nix
echo "==> 生成 default.nix"
STATE_VERSION="$(nixos-version 2>/dev/null | cut -d. -f1-2 || echo '25.11')"
cat > "hosts/$HOSTNAME/default.nix" << NIXEOF
{ config, pkgs, ... }:

{
  imports = [
    ./hardware-configuration.nix
    ./gpu.nix
    ../../modules/system/config.nix
    ../../modules/system/i18n.nix
    ../../modules/system/desktop.nix
    ../../modules/system/fonts.nix
    ../../modules/system/networking.nix
    ../../modules/system/nix.nix
    ../../modules/system/packages.nix
    ../../modules/system/services.nix
    ../../modules/system/users.nix
  ];

  boot.loader = {
    efi.canTouchEfiVariables = true;
    systemd-boot.enable = true;
  };

  boot.kernelPackages = pkgs.linuxPackages_latest;

  networking.hostName = "$HOSTNAME";

  system.stateVersion = "$STATE_VERSION";
}
NIXEOF

# 4. 复制 gpu.nix 模板
echo "==> 复制 gpu.nix 模板（请按实际 GPU 修改）"
cp hosts/mooling-laptop/gpu.nix "hosts/$HOSTNAME/gpu.nix"

# 5. 移除模板机器
echo "==> 移除模板 hosts/mooling-laptop/"
rm -rf hosts/mooling-laptop

# 6. 更新 flake.nix
echo "==> 更新 flake.nix"
sed -i "s/username = \"mooling\"/username = \"$USERNAME\"/" flake.nix
sed -i "s/mooling-laptop/$HOSTNAME/g" flake.nix

# 7. 更新 Git 配置
echo "==> 更新 Git 配置"
sed -i "s/settings.user.name = \".*\"/settings.user.name = \"$GIT_NAME\"/" modules/home/git.nix
sed -i "s/settings.user.email = \".*\"/settings.user.email = \"$GIT_EMAIL\"/" modules/home/git.nix

echo ""
echo "密码请在重建后用 passwd 设置:"
echo "  sudo passwd $USERNAME"
echo ""
echo "=== 部署准备完成 ==="
echo ""
echo "请检查 git diff 确认变更，然后运行:"
echo "  sudo nixos-rebuild switch --flake ~/nixos-config#$HOSTNAME"
