{
  # 选区录屏开关脚本（gpu-screen-recorder + slurp）。
  # 由 ~/.config/niri/config.kdl 的 Mod+Alt+G 绑定调用：
  # 首次按下 slurp 选区并开始录制，再次按下 SIGINT 停止并落盘。
  # 不声明式管理 niri 配置本身（见 AGENTS.md 关键设计决策 1）。
  home.file.".local/bin/region-record" = {
    text = ''
      #!/usr/bin/env bash
      # 选区录屏开关：Win+Alt+G
      set -euo pipefail
      PIDFILE="/run/user/$UID/region-record.pid"
      DIR="$HOME/Videos/ScreenrnRecords"
      mkdir -p "$DIR"

      if [[ -f "$PIDFILE" ]] && kill -0 "$(cat "$PIDFILE")" 2>/dev/null; then
          kill -INT "$(cat "$PIDFILE")" 2>/dev/null || true
          rm -f "$PIDFILE"
          notify-send -t 1500 "选区录屏" "已停止并保存到 $DIR"
          exit 0
      fi
      rm -f "$PIDFILE"

      # slurp 输出 "X,Y WxH" → gpu-screen-recorder 的 "WxH+X+Y"
      GEOM="$(slurp)" || exit 0
      [[ -n "$GEOM" ]] || exit 0
      REGION="$(printf '%s\n' "$GEOM" | awk -F'[, x+]+' '{print $3"x"$4"+"$1"+"$2}')"

      FILE="$DIR/region-$(date +%Y%m%d_%H%M%S).mkv"
      notify-send -t 1500 "选区录屏" "开始录制 $GEOM"
      gpu-screen-recorder \
          -w region \
          -region "$REGION" \
          -f 60 \
          -k hevc \
          -q high \
          -a default_output \
          -o "$FILE" &
      echo $! > "$PIDFILE"
    '';
    executable = true;
  };
}
