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
      # 清理上次运行残留的 timer 令牌
      rm -f /dev/shm/apollo-timer-* 2>/dev/null

      # 启动时关闭虚拟屏，只保留主屏
      ${wlr-randr} --output HDMI-A-1 --off

      timer_token=""
      client_attempting="false"
      client_device=""
      client_mode="${default-mode}"
      client_scale="1"

      # 文件令牌：timer 后台进程醒来时检查令牌文件是否仍存在
      # 被 cancel 时删除文件，后台进程检查文件不存在即退出
      cancel_timer() {
        [ -n "$timer_token" ] && rm -f "$timer_token" 2>/dev/null
        timer_token=""
      }

      start_idle_timer() {
        cancel_timer
        timer_token="/dev/shm/apollo-timer-idle-$$-$RANDOM"
        : > "$timer_token"
        (
          sleep 300
          [ -f "$timer_token" ] || exit 0
          rm -f "$timer_token"
          ${wlr-randr} --output eDP-1 --on --pos 0,0
          ${wlr-randr} --output HDMI-A-1 --off
        ) &
      }

      start_disconnect_timer() {
        cancel_timer
        timer_token="/dev/shm/apollo-timer-disc-$$-$RANDOM"
        : > "$timer_token"
        (
          sleep 5
          [ -f "$timer_token" ] || exit 0
          rm -f "$timer_token"
          ${wlr-randr} --output HDMI-A-1 --off
          ${wlr-randr} --output eDP-1 --on --pos 0,0
        ) &
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
            ${wlr-randr} --output HDMI-A-1 --on --custom-mode "$client_mode" --scale "$client_scale" --pos 0,0
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
      KillMode = "process";
    };
    Install = {
      WantedBy = [ "graphical-session.target" ];
    };
  };
}
