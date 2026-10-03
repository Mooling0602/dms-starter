#!/usr/bin/env bash
#
# 求值检查：打印某台主机的 system.build.toplevel 派生路径。
# 只做求值（nix eval），不构建、不切换系统。
#
# 用法：
#   ./eval-check.sh [hostname]
#
#   hostname   hosts/ 下的主机目录名；省略时为 mooling-laptop。
#
# stdout 只有派生路径，可直接管道使用；提示与错误一律走 stderr。

set -euo pipefail

DEFAULT_HOST="mooling-laptop"

REPO_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
cd "$REPO_ROOT"

die() {
  echo "错误：$*" >&2
  exit 1
}

# 与 flake.nix 的枚举口径一致：hosts/<name>/ 是目录且其中含 default.nix。
# 仅存在目录但没有 default.nix 时 flake 不会生成该主机的 nixosConfiguration，
# 这里也就不能把它当成有效主机。
available_hosts() {
  local d
  for d in hosts/*/; do
    [ -f "$d/default.nix" ] || continue
    basename "$d"
  done
}

[ "$#" -le 1 ] || die "参数过多：$*（用法：$(basename "$0") [hostname]）"

[ -d hosts ] || die "仓库根目录下缺少 hosts/，无法枚举主机。"

# 显式传入空串（例如引用了未定义变量）视为错误，而不是回退到默认主机：
# 否则会在检查了另一台主机的配置后静默成功，误导使用者。
if [ "$#" -eq 0 ]; then
  HOST="$DEFAULT_HOST"
else
  HOST="$1"
  [ -n "$HOST" ] || die "主机名不能为空（用法：$(basename "$0") [hostname]）。"
fi

if [ ! -f "hosts/$HOST/default.nix" ]; then
  die "主机 '${HOST}' 不存在（缺少 hosts/${HOST}/default.nix）。可用主机：$(
    available_hosts | tr '\n' ' '
  )"
fi

command -v nix >/dev/null 2>&1 || die "找不到 nix 命令。"

# --raw 不加尾换行，这里补一个：输出落到终端或按行消费时更自然，
# 需要精确字节时仍可用 $(...) 去掉。
nix eval --raw ".#nixosConfigurations.${HOST}.config.system.build.toplevel.drvPath"
echo
