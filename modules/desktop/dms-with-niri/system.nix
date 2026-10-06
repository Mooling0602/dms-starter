{
  config,
  inputs,
  ...
}:

# system module for the setup of desktop module dms-with-niri

let
  # This implementation's desktop name, derived from this file's own directory
  # (modules/desktop/<name>/). Not hardcoded, so the assertion follows a rename
  # instead of drifting from the directory name. Bare baseNameOf is used because
  # it is in the Nix prelude (equivalent to builtins.baseNameOf).
  desktopName = baseNameOf ./.;
in
{
  # Used by the fallback assertion in modules/system/config.nix: only set when
  # this module is present. Stays false when the desktop layer is imported but
  # the implementation is missing from `imports`, and that side reports it.
  my.desktopImplementationLoaded = true;

  # This module asserts that it is the desktop declared by my.desktop. Placing
  # it in the implementation rather than in hosts/<host>/desktop/<name>/ means
  # only the implementation knows generically which desktop is actually loaded,
  # so the half-wrong case (declared A but imported B) is caught on any host,
  # not just the missing-import case.
  assertions = [
    {
      assertion = config.my.desktop == desktopName;
      message = ''
        桌面模块不一致：my.desktop 声明的是 "${config.my.desktop}"，
        但实际加载的桌面实现是 "${desktopName}"。

        当前加载的是 modules/desktop/${desktopName}/system.nix。
        通常意味着 hosts/<host>/default.nix 顶部的 `desktop` let 绑定与
        hosts/<host>/desktop/${config.my.desktop}/default.nix 里 import 的实现
        不是同一个：前者决定 my.desktop，后者决定实际加载哪个实现。
      '';
    }
  ];

  # This desktop's own Home Manager modules are mounted here, so dms-shell,
  # dsearch and dank-calendar enter the user environment only when dms-with-niri
  # is selected. Desktop-independent HM config stays in modules/home/ and is
  # imported unconditionally by flake.nix.
  # These used to be hardcoded in flake.nix's home-manager.users.<name>.imports,
  # so they stayed active after switching to kde-plasma (leftover dms.service,
  # dsearch.service, ...).
  home-manager.sharedModules = [
    ./default.nix
    inputs.dms.homeModules.dank-material-shell
    inputs.danksearch.homeModules.dsearch
    inputs.dankcalendar.homeModules.dank-calendar
  ];

  services.displayManager.dms-greeter = {
    enable = true;
    compositor.name = "niri";
    configHome = "/home/${config.my.username}";
  };

  programs.niri = {
    enable = true;
  };

  users.users.${config.my.username} = {
    extraGroups = [
      "dms-greeter"
    ];
  };

  # DMS uses a dedicated PAM service for the lock screen. Follow the howdy
  # module instead of forcing face auth on: with `services.howdy` disabled the
  # lock screen keeps its plain password stack (pam_unix + pam_deny).
  # Keep this assignment unconditional: it is the only thing that registers
  # /etc/pam.d/dankshell, and DMS only falls back to its own
  # ~/.local/state/pam/dankshell when that file is absent (#2789).
  security.pam.services.dankshell.howdy.enable = config.services.howdy.enable;

  # gpu-screen-recorder's KMS capture escalates via pkexec
  # (org.freedesktop.policykit.exec), which normally prompts for a password on
  # every recording. Allow wheel-group members in local sessions to run it
  # without a password. The program match uses the nix store path fragment
  # "-gpu-screen-recorder-" to avoid version drift. Having the rule when
  # gpu-screen-recorder is not active in the current environment should be
  # harmless.
  security.polkit.extraConfig = ''
    polkit.addRule(function(action, subject) {
        if (action.id == "org.freedesktop.policykit.exec" &&
            subject.isInGroup("wheel") && subject.local) {
            var program = action.lookup("program");
            if (program && program.indexOf("-gpu-screen-recorder-") !== -1) {
                return polkit.Result.YES;
            }
        }
    });
  '';
}
