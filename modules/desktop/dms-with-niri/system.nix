{
  config,
  inputs,
  ...
}:

# system module for the setup of desktop module dms-with-niri

let
  # 本实现的桌面名，从本文件实际所在的目录名推导（modules/desktop/<name>/）。
  # 不手写字符串，因此目录被重命名时断言会自动跟着变，不会和目录名漂移。
  # 用裸 baseNameOf：它在 Nix prelude 中（与 builtins.baseNameOf 等价）。
  desktopName = baseNameOf ./.;
in
{
  # 供 modules/system/config.nix 的兜底断言使用：只有本模块存在时才会置位。
  # 「桌面层导入了、imports 里却漏掉实现」时它保持 false，由那边报错。
  my.desktopImplementationLoaded = true;

  # 本模块直接断言自己就是 my.desktop 声明的那个桌面。放在实现模块而非
  # hosts/<host>/desktop/<name>/ 那一层：只有实现模块才通用地知道「实际加载
  # 的是哪个桌面」，这样「层导入了、但忘了导入实现」以外的半对半错
  # （声明 A 却导入了 B 的实现）才能在任何主机上被捕获。
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

  # 本桌面专属的 Home Manager 模块由这一层自己挂载：只有选中 dms-with-niri 时，
  # dms-shell、dsearch、dank-calendar 才会进入用户环境。桌面无关的 HM 配置仍在
  # modules/home/，由 flake.nix 无条件导入。
  # 之前这些模块写死在 flake.nix 的 home-manager.users.<name>.imports 里，
  # 导致切到 kde-plasma 后它们仍然生效（残留 dms.service、dsearch.service 等）。
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
