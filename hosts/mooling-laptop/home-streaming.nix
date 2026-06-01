{ pkgs, lib, hostname, ... }:

lib.mkIf (hostname == "mooling-laptop") {
  systemd.user.services.virtual-display-mode = let
    wlr-randr = "${pkgs.wlr-randr}/bin/wlr-randr";
  in {
    Unit = {
      Description = "Add custom modes to virtual display HDMI-A-1";
      After = [ "graphical-session.target" ];
      PartOf = [ "graphical-session.target" ];
    };
    Service = {
      Type = "oneshot";
      ExecStart = "${wlr-randr} --output HDMI-A-1 --custom-mode '2460x1080@60Hz'";
      RemainAfterExit = true;
    };
    Install = {
      WantedBy = [ "graphical-session.target" ];
    };
  };

  systemd.user.services.apollo-display-toggle = let
    wlr-randr = "${pkgs.wlr-randr}/bin/wlr-randr";
    toggleScript = pkgs.writeShellScript "apollo-display-toggle" ''
      journalctl --user -u apollo.service -f -n 0 | while read -r line; do
        if echo "$line" | grep -q "CLIENT CONNECTED"; then
          sleep 2
          ${wlr-randr} --output eDP-1 --off
          ${wlr-randr} --output HDMI-A-1 --custom-mode '2460x1080@60Hz' --on --pos 0,0
        elif echo "$line" | grep -q "CLIENT DISCONNECTED"; then
          ${wlr-randr} --output HDMI-A-1 --off
          ${wlr-randr} --output eDP-1 --on --pos 0,0
        fi
      done
    '';
  in {
    Unit = {
      Description = "Auto-toggle displays when Apollo client connects/disconnects";
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
