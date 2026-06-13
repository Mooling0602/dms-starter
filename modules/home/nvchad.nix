{ pkgs, dms, ... }:

{
  programs.nvchad = {
    enable = true;
    extraPackages = with pkgs; [
      nixd
      lua-language-server
      bash-language-server
      python3Packages.python-lsp-server
      stylua
      dms.packages.${pkgs.stdenv.hostPlatform.system}.default
    ];
    backup = true;
  };
}
