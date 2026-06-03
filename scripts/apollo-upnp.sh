#!/usr/bin/env bash
set -euo pipefail

LOCAL_IP="192.168.6.236"
ROUTER="http://192.168.6.1:5000/rootDesc.xml"

# Apollo/Sunshine 需要的端口: port protocol
PORTS=(
  "47989 TCP"
  "47990 TCP"
  "48010 TCP"
  "47998 UDP"
  "47999 UDP"
  "48000 UDP"
  "48002 UDP"
  "48010 UDP"
)

RELOAD_NETWORK=false

check_deps() {
  if ! command -v upnpc &>/dev/null; then
    echo "错误: upnpc 未安装。运行: nix-shell -p miniupnpc"
    exit 1
  fi
}

reload_network() {
  echo "==> 重启 NetworkManager..."
  sudo systemctl restart NetworkManager
  echo "==> 等待网络恢复..."
  for i in $(seq 1 15); do
    if nmcli -t -f STATE general 2>/dev/null | grep -q "connected"; then
      echo "==> 网络已连接"
      return 0
    fi
    sleep 1
  done
  echo "==> 警告: 网络未在 15 秒内恢复"
}

cmd_add() {
  echo "==> 添加 Apollo UPnP 端口转发..."
  for entry in "${PORTS[@]}"; do
    read -r port proto <<<"$entry"
    echo -n "  $port/$proto ... "
    upnpc -e "Apollo-$port" -a "$LOCAL_IP" "$port" "$port" "$proto" 2>/dev/null | grep -q "successfully\|already" \
      && echo "ok" || echo "failed"
  done
  echo "==> 完成"
}

cmd_delete() {
  echo "==> 删除 Apollo UPnP 端口转发..."
  for entry in "${PORTS[@]}"; do
    read -r port proto <<<"$entry"
    echo -n "  $port/$proto ... "
    upnpc -d "$port" "$proto" 2>/dev/null | grep -q "success" \
      && echo "ok" || echo "failed"
  done
  echo "==> 完成"
}

cmd_status() {
  echo "==> UPnP 端口转发状态:"
  upnpc -l 2>/dev/null | grep -iE 'apollo|47989|47990|48010|47998|47999|48000|48002' || echo "  无 Apollo 相关映射"
}

usage() {
  cat <<EOF
用法: $0 {add|delete|status} [--reload-network]

  add       添加 Apollo 所需端口的 UPnP 映射
  delete    删除所有 Apollo 端口的 UPnP 映射
  status    查看当前 UPnP 映射状态

选项:
  --reload-network  操作前先重启 NetworkManager（用于 UPnP 发现失效时）
EOF
  exit 1
}

check_deps

# Parse --reload-network flag
for arg in "$@"; do
  [[ "$arg" == "--reload-network" ]] && RELOAD_NETWORK=true
done
set -- "${@//--reload-network/}"

$RELOAD_NETWORK && reload_network

case "${1:-}" in
  add)    cmd_add ;;
  delete) cmd_delete ;;
  status) cmd_status ;;
  *)      usage ;;
esac
