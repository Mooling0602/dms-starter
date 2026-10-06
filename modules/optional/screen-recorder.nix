{ pkgs, ... }:

# Home-manager module, can be imported in user space.

{
  home.packages = with pkgs; [
    grim
    slurp
    satty

    # virtual display mode utility
    wlr-randr
  ];

  # Region-recording toggle script (gpu-screen-recorder + slurp).
  # Invoked from the Mod+Alt+G binding in ~/.config/niri/config.kdl:
  # the first press selects a region with slurp and starts recording, the next
  # sends SIGINT to stop and flush the file.
  # niri's own config is intentionally not managed declaratively (see key
  # design decision 1 in AGENTS.md).
  home.file.".local/bin/region-record" = {
    text = ''
      #!/usr/bin/env bash
      # Region recording toggle: Win+Alt+G
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

      # slurp prints "X,Y WxH" -> gpu-screen-recorder wants "WxH+X+Y"
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
