#!/usr/bin/env bash
#
# 新机器部署 / 已有机器重新初始化。
#
# 用法：
#   cd ~/nixos-config && ./deploy.sh
#
# 流程：
#   1. 以 hosts/*/hardware-configuration.nix 是否存在判定新机器
#   2. 采集用户名与主机名（直接回车取已有 host 目录中的当前值）
#   3. 创建 assets/<username>、modules/home/<username>、hosts/<hostname>、
#      hosts/<hostname>/desktop/<desktop>、user_profiles/<username>
#   4. flake.nix 无需改动：主机由 hosts/ 目录枚举，身份写在 hosts/<hostname>/default.nix
#   5. 生成硬件配置到 hosts/<hostname>/，并据此写出该机器的 default.nix
#      与 hosts/<hostname>/desktop/<desktop>/default.nix（桌面分层，见 README「桌面模块」）
#   6. 设置登录密码（已有机器上改为先询问是否重设）
#   7. 暂存本次新增内容后，询问并执行一次 sudo nixos-rebuild switch --flake .#<hostname>
#
# 已有机器上第 3、5 步是覆盖操作，本脚本不回滚，需要你自己用 git 恢复。

set -euo pipefail

REPO_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
cd "$REPO_ROOT"

[ -f flake.nix ] || {
  echo "错误：$REPO_ROOT 下没有 flake.nix，请把本脚本放在仓库根目录运行。" >&2
  exit 1
}

# ---------------------------------------------------------------- 工具函数

step() {
  echo ""
  echo "==> $*"
}

die() {
  echo "错误：$*" >&2
  exit 1
}

# 枚举主机与读取身份都依赖 hosts/ 存在（flake 的 readDir ./hosts 同理）
[ -d hosts ] || die "仓库根目录下缺少 hosts/，无法枚举主机。"

# 读取已存在主机的用户名；flake.nix 不再承载用户名/主机名。
flake_value() {
  local key="$1" host_dir
  host_dir="$(existing_host_dir)"
  [ -n "$host_dir" ] || return 0
  sed -n "s/^[[:space:]]*my\.$key = \"\([^\"]*\)\";.*$/\1/p" "$host_dir/default.nix" | head -n1
}

# 读取已存在主机使用的桌面模块名（hosts/<host>/default.nix 顶部的 let 绑定）。
# 旧结构（imports 里直接写 modules/desktop/<name>/system.nix）读不到，返回空。
flake_desktop() {
  local host_dir
  host_dir="$(existing_host_dir)"
  [ -n "$host_dir" ] || return 0
  sed -n 's/^[[:space:]]*desktop = "\([^"]*\)";.*$/\1/p' "$host_dir/default.nix" | head -n1
}

# 主机名即 hosts/<host>/ 的目录名（flake.nix 用目录名注入 hostname）
existing_hostname() {
  local host_dir
  host_dir="$(existing_host_dir)"
  [ -n "$host_dir" ] || return 0
  printf '%s' "${host_dir#hosts/}"
}

# 列出 hosts/ 下的主机目录名（只认含 default.nix 的目录）
host_dirs() {
  local d
  for d in hosts/*/; do
    [ -f "$d/default.nix" ] || continue
    printf '%s\n' "${d#hosts/}" | sed 's:/$::'
  done
}

# 供交互默认值使用的主机目录：与当前 hostname 同名者优先，否则唯一主机
existing_host_dir() {
  local names name
  names="$(host_dirs)"
  [ -n "$names" ] || return 0
  name="$(hostname 2>/dev/null || true)"
  if [ -n "$name" ] && [ -f "hosts/$name/default.nix" ]; then
    printf 'hosts/%s' "$name"
    return 0
  fi
  if [ "$(printf '%s\n' "$names" | wc -l)" -eq 1 ]; then
    printf 'hosts/%s' "$names"
  fi
}

# 带默认值的提问，直接回车即取默认值
ask() {
  local prompt="$1" default="$2" reply
  read -rp "$prompt [$default]: " reply
  printf '%s' "${reply:-$default}"
}

# 仅 y/Y/yes/YES 视为确认
confirm() {
  local reply
  read -rp "$1 " reply
  case "$reply" in
    y | Y | yes | YES) return 0 ;;
    *) return 1 ;;
  esac
}

# 仓库不跟踪 hosts/*/hardware-configuration.nix，全新克隆时一个都不存在
is_new_machine() {
  local existing
  existing="$(compgen -G 'hosts/*/hardware-configuration.nix' || true)"
  [ -z "$existing" ]
}

# 探测 GRUB 的安装目标：
#   - EFI 固件 → nodev（GRUB 只写 ESP，不碰 MBR）
#   - 否则回溯 /boot（没有独立 /boot 时用 /）所在的物理磁盘，
#     RAID 会把成员盘全部列出，交给 devices 列表
detect_grub_devices() {
  if [ -d /sys/firmware/efi ]; then
    printf 'nodev'
    return 0
  fi

  local target src disks
  for target in /boot /; do
    src="$(findmnt -no SOURCE --target "$target" 2>/dev/null || true)"
    [ -n "$src" ] || continue
    # lsblk -s 逆序回溯父设备，会跳过 part/lvm/crypt/raid 直到物理磁盘
    disks="$(lsblk -sno NAME,TYPE "$src" 2>/dev/null | awk '$2 == "disk" { printf "/dev/%s ", $1 }')"
    [ -n "$disks" ] || continue
    printf '%s' "${disks% }"
    return 0
  done

  return 1
}

# 设备列表 → Nix 行；多块盘（RAID）时用 devices 列表
render_grub_devices() {
  local -a devs=($1)
  if [ "${#devs[@]}" -gt 1 ]; then
    printf '  boot.loader.grub.devices = ['
    printf ' "%s"' "${devs[@]}"
    printf ' ];\n'
  else
    printf '  boot.loader.grub.device = "%s";\n' "${devs[0]}"
  fi
}

# 需要 GRUB 时确定安装设备：探测成功回车即采用，也可手动改写；
# 探测不到就交回用户自己在主机配置里补全，不代为猜测
ask_grub_devices() {
  local detected reply value dev
  detected="$(detect_grub_devices || true)"

  if [ -z "$detected" ]; then
    echo "警告：未能自动探测 GRUB 安装设备（没有 EFI 固件，且 /boot、/ 都无法回溯到物理磁盘）。" >&2
    echo "      boot.loader.grub.device 留空，重建会在求值阶段报错：" >&2
    echo "      You must set the option 'boot.loader.grub.devices' or 'boot.loader.grub.mirroredBoots' to make the system bootable." >&2
    echo "      请在 hosts/$HOSTNAME/default.nix 中自行补全后重试。" >&2
    return 1
  fi

  echo "已探测到 GRUB 安装设备：$detected" >&2
  read -rp "回车采用该值，或输入其他设备（EFI 机器可填 nodev）: " reply
  value="${reply:-$detected}"

  value="${value//,/ }"
  for dev in $value; do
    [[ "$dev" =~ ^(/dev/[A-Za-z0-9/_.-]+|nodev)$ ]] || die "无效的 GRUB 设备：$dev"
  done
  [ -n "$value" ] || die "未提供 GRUB 安装设备。"

  printf '%s' "$value"
}

# 只暂存真实存在的文件，空目录不进版本库
stage() {
  local p="$1"
  [ -e "$p" ] || return 0
  if [ -d "$p" ] && [ -z "$(find "$p" -type f -print -quit)" ]; then
    return 0
  fi
  git add -- "$p"
}

# ------------------------------------------------------------ 1. 机器判定

NEW_MACHINE=false
if is_new_machine; then
  NEW_MACHINE=true
  echo "未找到 hosts/*/hardware-configuration.nix，按新机器处理。"
else
  echo "检测到已存在的 hardware-configuration.nix，按已有机器处理。"
  echo "初始化流程会覆盖 assets/、modules/home/、hosts/、user_profiles/ 下的同名内容，"
  echo "且无法由本脚本回滚（需要你自己用 git 恢复）。"
  if ! confirm "继续执行初始化流程？[y/N]"; then
    echo "已取消，未做任何修改。"
    exit 0
  fi
fi

DEFAULT_USERNAME="$(flake_value username)"
DEFAULT_HOSTNAME="$(existing_hostname)"
DEFAULT_DESKTOP="$(flake_desktop)"
[ -n "$DEFAULT_USERNAME" ] || die "无法从 hosts/*/default.nix 读取 my.username 默认值。"
[ -n "$DEFAULT_HOSTNAME" ] || die "无法从 hosts/*/ 的目录名确定主机名默认值。"
DEFAULT_DESKTOP="${DEFAULT_DESKTOP:-dms-with-niri}"

# --------------------------------- 2. 用户名、主机名与桌面模块（1.1.1/1.1.2）

step "设置用户名与主机名"
USERNAME="$(ask '用户名' "$DEFAULT_USERNAME")"
HOSTNAME="$(ask '主机名' "$DEFAULT_HOSTNAME")"

[[ "$USERNAME" =~ ^[a-z_][a-z0-9_-]*$ ]] ||
  die "用户名不合法：$USERNAME（仅允许小写字母、数字、下划线与短横线，且不以数字开头）"
[[ "$HOSTNAME" =~ ^[a-zA-Z0-9][a-zA-Z0-9-]*$ ]] ||
  die "主机名不合法：$HOSTNAME（仅允许字母、数字与短横线）"

# 桌面模块名必须是仓库里真实存在的目录，否则生成的 imports 会指向不存在的
# 路径，重建时在求值阶段报 "path does not exist in Git repository"。
# 名字写错只需重问，不必中断整个部署流程。
step "选择桌面模块"
while :; do
  DESKTOP="$(ask '桌面模块名' "$DEFAULT_DESKTOP")"
  if [[ ! "$DESKTOP" =~ ^[a-z0-9][a-z0-9_-]*$ ]]; then
    echo "桌面模块名不合法：$DESKTOP（仅允许小写字母、数字、下划线与短横线）" >&2
    continue
  fi
  if [ ! -f "modules/desktop/$DESKTOP/system.nix" ]; then
    echo "modules/desktop/$DESKTOP/system.nix 不存在。可选：$(
      ls -1d modules/desktop/*/ 2>/dev/null |
        while read -r d; do [ -f "$d/system.nix" ] && basename "$d"; done | tr '\n' ' '
    )" >&2
    continue
  fi
  break
done
echo "已选择 desktop = \"$DESKTOP\"（实现来自 modules/desktop/$DESKTOP/）"

# ---------------------------------------------------- 3. 创建目录（1.1.3）

step "创建目录"
mkdir -p "assets/$USERNAME" "user_profiles/$USERNAME" "hosts/$HOSTNAME"
# 主机专属的桌面配置目录；my.desktopLayer 的一致性由 modules/system/config.nix
# 的断言保证，此处只需保证 default.nix 存在且导入对应实现。
mkdir -p "hosts/$HOSTNAME/desktop/$DESKTOP"

# 个人模块目录：模块本身由用户自行编写（旧版 modules/home/user 模板已于
# a3328c3 移除，不再复制）。这里只保证目录存在，home/default.nix 通过
# optionalImports 容忍其下的文件缺失。
mkdir -p "modules/home/$USERNAME"
if [ -z "$(ls -A "modules/home/$USERNAME")" ]; then
  echo "已创建空的 modules/home/$USERNAME，请按需添加 git.nix、packages.nix 等模块。"
else
  echo "modules/home/$USERNAME 已存在文件，保留原内容。"
fi

# --------------------------------------- 4. flake.nix 不变式检查（1.1.4）

step "检查 flake.nix 不承载设备身份"
# 主机由 hosts/*/ 目录枚举，身份写在 hosts/<hostname>/default.nix；
# flake.nix 里出现具体用户名/主机名就说明有人把身份写回去了。
if grep -nF -e "\"$USERNAME\"" -e "\"$HOSTNAME\"" flake.nix; then
  die "flake.nix 中出现硬编码身份（$USERNAME / $HOSTNAME），请移除后重试。"
fi
echo "flake.nix 未包含硬编码身份，符合预期。"

# ------------------------------------- 5. 生成硬件配置与主机配置（1.1.5）

step "生成硬件配置到 hosts/$HOSTNAME/"
sudo nixos-generate-config --root / --dir "hosts/$HOSTNAME"

HARDWARE_CONFIG="hosts/$HOSTNAME/hardware-configuration.nix"
GENERATED_CONFIG="hosts/$HOSTNAME/configuration.nix"
HOST_MODULE="hosts/$HOSTNAME/default.nix"

[ -f "$HARDWARE_CONFIG" ] || die "未生成 $HARDWARE_CONFIG，请检查 nixos-generate-config 的输出。"

# 生成的 configuration.nix 只用于取机器相关的引导器设置；hostName、stateVersion、
# users 等由本仓库模块提供，因此不保留该文件。
BOOT_LOADER_LINES=""
if [ -f "$GENERATED_CONFIG" ]; then
  BOOT_LOADER_LINES="$(grep -E '^[[:space:]]*boot\.loader\.' "$GENERATED_CONFIG" || true)"
  rm -f "$GENERATED_CONFIG"
fi

GRUB_DEVICES=""
GRUB_UNRESOLVED=false
if [ -e "$HOST_MODULE" ]; then
  echo "$HOST_MODULE 已存在，保留原文件不覆盖。"
else
  # 上游把 grub.device 留成注释（避免猜错盘把引导器写到别的磁盘上），
  # 这里用探测结果补全，并在写盘前让用户确认或改写。
  if grep -qE '^[[:space:]]*boot\.loader\.grub\.enable = true;' <<< "$BOOT_LOADER_LINES"; then
    if GRUB_DEVICES="$(ask_grub_devices)"; then
      BOOT_LOADER_LINES="${BOOT_LOADER_LINES}"$'\n'"$(render_grub_devices "$GRUB_DEVICES")"
    else
      GRUB_DEVICES=""
      GRUB_UNRESOLVED=true
    fi
  fi

  STATE_VERSION="$(nixos-version 2>/dev/null | cut -d. -f1-2 || true)"
  STATE_VERSION="${STATE_VERSION:-25.11}"

  # 桌面名用 let 绑定而非 config.my.desktop：imports 的求值早于 config，
  # 引用 config 会触发 infinite recursion。同一个 let 值同时喂给 my.desktop
  # 与下面的 import 路径，两者不会脱节（另有一致性断言兜底）。
  # 注意 ./desktop/\${desktop}/ 里的 \${} 必须转义，否则会被本脚本的
  # heredoc 提前展开成空串。
  cat > "$HOST_MODULE" << NIXEOF
{ config, hostname, ... }:

let
  # 本机使用的桌面模块名，对应 ./desktop/<desktop>/。
  desktop = "$DESKTOP";
in

{
  # ── 设备身份（本机唯一改动点）────────────────────────────────
  # flake.nix 只枚举 hosts/ 目录名并注入 hostname，其余设备改自己的目录。
  my.username = "$USERNAME";
  my.hostname = hostname;
  my.desktop = desktop;
  # ───────────────────────────────────────────────────────────

  imports = [
    ./hardware-configuration.nix
    ../../modules/system/config.nix
    ../../modules/system/i18n.nix
    ../../modules/system/fonts.nix
    ../../modules/system/networking.nix
    ../../modules/system/keyring.nix
    ../../modules/system/nix.nix
    ../../modules/system/packages.nix
    ../../modules/system/services.nix
    ../../modules/system/users.nix
    ../../modules/system/virtualisation.nix
    ./desktop/\${desktop}/default.nix
  ];

$BOOT_LOADER_LINES

  networking.hostName = config.my.hostname;

  system.stateVersion = "$STATE_VERSION";
}
NIXEOF

  echo "已生成 $HOST_MODULE。"

  # 主机专属的桌面层：导入 modules/desktop/<name>/ 的实现。它必须导入对应
  # 实现模块，否则 my.desktopLayer 无人赋值，一致性断言会在求值阶段报错。
  DESKTOP_MODULE="hosts/$HOSTNAME/desktop/$DESKTOP/default.nix"
  if [ -e "$DESKTOP_MODULE" ]; then
    echo "$DESKTOP_MODULE 已存在，保留原文件不覆盖。"
  else
    cat > "$DESKTOP_MODULE" << NIXEOF
# No host specific configurations needed here at present.

{
  imports = [
    ../../../../modules/desktop/$DESKTOP/system.nix
  ];
}
NIXEOF
    echo "已生成 $DESKTOP_MODULE。"
  fi

  if [ -n "$GRUB_DEVICES" ]; then
    echo "GRUB 安装设备：$GRUB_DEVICES（如与实际引导顺序不符，请修改 $HOST_MODULE）"
  fi
fi

# ------------------------------------------------- 6. 登录密码（1.1.6/2.1）

step "设置登录密码"
if [ "$NEW_MACHINE" = true ]; then
  sudo passwd "$USERNAME"
elif confirm "是否重设 $USERNAME 的登录密码？[y/N]"; then
  sudo passwd "$USERNAME"
else
  echo "已跳过密码设置。"
fi

# --------------------------------------------------- 7. 重建切换（第 3 条）

step "暂存本次变更"
# flake 源只包含 git 已跟踪的文件：新增目录必须 add，被 .gitignore 忽略的
# hardware-configuration.nix 必须 -f add，否则重建求值时会报路径不存在。
# flake.nix 在方案 A 下无需改动，但仍一并暂存以防有手动调整。
git add -- flake.nix
git add -f -- "$HARDWARE_CONFIG"
stage "hosts/$HOSTNAME"
stage "assets/$USERNAME"
stage "user_profiles/$USERNAME"
stage "modules/home/$USERNAME"
git status --short -- "hosts/$HOSTNAME" "assets/$USERNAME" "user_profiles/$USERNAME" "modules/home/$USERNAME" flake.nix

step "系统重建切换"
if confirm "确认现在重建并切换？[y/N]"; then
  sudo nixos-rebuild switch --flake ".#$HOSTNAME"
else
  echo "已跳过重建。稍后可手动运行：sudo nixos-rebuild switch --flake .#$HOSTNAME"
fi

echo ""
echo "=== 部署流程结束 ==="
echo "用户名：$USERNAME"
echo "主机名：$HOSTNAME"
if [ -n "$GRUB_DEVICES" ]; then
  echo "GRUB 安装设备：$GRUB_DEVICES"
fi
if [ "$GRUB_UNRESOLVED" = true ]; then
  echo "注意：boot.loader.grub.device 未填写，重建前请在 hosts/$HOSTNAME/default.nix 中补全，"
  echo "      否则求值会因为 grub 的 mirroredBoots 断言直接失败。"
fi
echo "机器配置：hosts/$HOSTNAME/default.nix（请按实际硬件补全 GPU 等机器专属配置）"
