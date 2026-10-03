{
  config,
  ...
}:

# system module for the setup of desktop module dms-with-niri

{
  # 本模块自报家门，供 modules/system/config.nix 的断言与 my.desktop 对比。
  # 放在实现模块而非 hosts/<host>/desktop/<name>/ 那一层：只有这样才能通用地
  # 捕获「层导入了、但忘了导入实现」这类半对半错（曾经在 kde-plasma 上发生过）。
  my.desktopLayer = "dms-with-niri";

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
  # Keep this assignment unconditional - it is the only thing that registers
  # /etc/pam.d/dankshell, and DMS only falls back to its own
  # ~/.local/state/pam/dankshell when that file is absent (#2789).
  security.pam.services.dankshell.howdy.enable = config.services.howdy.enable;

  # gpu-screen-recorder 的 KMS 捕获经 pkexec 提权（org.freedesktop.policykit.exec），
  # 默认每次录屏都弹密码。放行 wheel 组本地会话成员对该程序的免密执行：
  # program 匹配 nix store 路径片段 "-gpu-screen-recorder-"，规避版本号漂移。
  # gpu-screen-recorder 即使没有在当前环境下激活，应该也没有影响。
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
