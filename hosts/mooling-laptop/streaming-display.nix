{ pkgs, lib, hostname, ... }:

let
  devices = import ./streaming-devices.nix;

  # 生成设备名 → 模式参数的 shell case 分支 (输出 "mode scale")
  device-case = lib.concatStringsSep "\n" (
    lib.mapAttrsToList (name: cfg: ''
      "${name}") echo "${toString cfg.width}x${toString cfg.height}@${toString cfg.refresh} ${toString (cfg.scale or 1)}" ;;
    '') devices
  );
in
lib.mkIf (hostname == "mooling-laptop") {
  systemd.user.services.apollo-display-toggle = let
    wlr-randr = "${pkgs.wlr-randr}/bin/wlr-randr";
    default-mode = "2460x1080@60";
    toggleScript = pkgs.writeShellScript "apollo-display-toggle" ''
      # 启动时关闭虚拟屏，只保留主屏
      ${wlr-randr} --output HDMI-A-1 --off

      timer_pid=""
      client_attempting="false"
      client_device=""
      client_mode="${default-mode}"
      client_scale="1"

      cancel_timer() {
        kill "$timer_pid" 2>/dev/null
        timer_pid=""
      }

      start_idle_timer() {
        cancel_timer
        (
          sleep 300
          ${wlr-randr} --output eDP-1 --on --pos 0,0
          ${wlr-randr} --output HDMI-A-1 --off
        ) &
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
        if echo "$line" | grep -q "Display mode for client"; then
          client_attempting="true"
          cancel_timer
          # 先回退到默认值，避免未知设备复用上一个设备的参数
          client_mode="${default-mode}"
          client_scale="1"
          # 提取设备名: "Display mode for client [NAME #tag]" → "NAME"
          client_device=$(echo "$line" | sed 's/.*Display mode for client \[\([^]]*\)\].*/\1/' | sed 's/ *#.*//')
          result=$(lookup_mode "$client_device")
          if [ -n "$result" ]; then
            client_mode=$(echo "$result" | awk '{print $1}')
            client_scale=$(echo "$result" | awk '{print $2}')
          fi
        elif echo "$line" | grep -q "Couldn't find monitor"; then
          if [ "$client_attempting" = "true" ]; then
            ${wlr-randr} --output eDP-1 --off
            ${wlr-randr} --output HDMI-A-1 --on --custom-mode "${default-mode}" --pos 0,0
            start_idle_timer
          fi
        elif echo "$line" | grep -q "CLIENT CONNECTED"; then
          cancel_timer
          sleep 2
          ${wlr-randr} --output HDMI-A-1 --custom-mode "$client_mode" --scale "$client_scale" --pos 0,0
        elif echo "$line" | grep -q "CLIENT DISCONNECTED"; then
          client_attempting="false"
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
