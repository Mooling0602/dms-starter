{ pkgs, lib, hostname, ... }:

let
  devices = import ./streaming-devices.nix;

  # 生成设备名 → 模式参数的 shell case 分支
  device-case = lib.concatStringsSep "\n" (
    lib.mapAttrsToList (name: cfg: ''
      "${name}") mode="${toString cfg.width}x${toString cfg.height}@${toString cfg.refresh}" ;;
    '') devices
  );
in
lib.mkIf (hostname == "mooling-laptop") {
  systemd.user.services.apollo-display-toggle = let
    wlr-randr = "${pkgs.wlr-randr}/bin/wlr-randr";
    default-mode = "2460x1080@60";
    toggleScript = pkgs.writeShellScript "apollo-display-toggle" ''
      timer_pid=""
      client_device=""
      client_mode="${default-mode}"

      cancel_timer() {
        kill "$timer_pid" 2>/dev/null
        timer_pid=""
      }

      start_idle_timer() {
        cancel_timer
        (sleep 300 && ${wlr-randr} --output HDMI-A-1 --off) &
        timer_pid=$!
      }

      start_disconnect_timer() {
        cancel_timer
        (
          sleep 5
          ${wlr-randr} --output HDMI-A-1 --off
          ${wlr-randr} --output eDP-1 --on --pos 0,0
        ) &
        timer_pid=$!
      }

      # 根据设备名查找对应的屏幕参数
      lookup_mode() {
        case "$1" in
      ${device-case}
        esac
      }

      journalctl --user -u apollo.service -f -n 0 | while read -r line; do
        if echo "$line" | grep -q "Couldn't find monitor"; then
          ${wlr-randr} --output HDMI-A-1 --on --custom-mode "${default-mode}" --pos 1463,0
          start_idle_timer
        elif echo "$line" | grep -q "Display mode for client"; then
          # 提取设备名: "Display mode for client [NAME #tag]" → "NAME"
          client_device=$(echo "$line" | sed 's/.*\[\([^]]*\)\].*/\1/' | sed 's/ *#.*//')
          client_mode=$(lookup_mode "$client_device")
        elif echo "$line" | grep -q "CLIENT CONNECTED"; then
          cancel_timer
          sleep 2
          ${wlr-randr} --output eDP-1 --off
          ${wlr-randr} --output HDMI-A-1 --custom-mode "$client_mode" --pos 0,0
        elif echo "$line" | grep -q "CLIENT DISCONNECTED"; then
          ${wlr-randr} --output eDP-1 --on --pos 0,0
          start_disconnect_timer
        fi
      done
    '';
  in {
    Unit = {
      Description = "Auto-manage displays for Apollo streaming";
      After = [ "graphical-session.target" ];
    };
    Service = {
      Type = "simple";
      ExecStart = "${toggleScript}";
      Restart = "on-failure";
      RestartSec = 5;
    };
    Install = {
      WantedBy = [ "graphical-session.target" ];
    };
  };
}
