{ ... }:

{
  nix.settings = {
    experimental-features = [
      "nix-command"
      "flakes"
    ];
    auto-optimise-store = true;
  };

  nix.gc = {
    automatic = true;
    dates = "weekly";
    options = "--delete-older-than 7d";
  };

  # 国内 Go 代理，解决 proxy.golang.org 无法访问的问题
  environment.variables.GOPROXY = "https://goproxy.cn,direct";

  # 让 sudo 保留 GOPROXY 环境变量（nixos-rebuild 需要）
  security.sudo.extraConfig = ''
    Defaults env_keep += "GOPROXY"
  '';

  programs.nix-ld.enable = true;
}
