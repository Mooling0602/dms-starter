{ pkgs, dmsPackage, ... }:

{
  programs.nvchad = {
    enable = true;
    extraPackages = with pkgs; [
      nixd
      lua-language-server
      bash-language-server
      python3Packages.python-lsp-server
      stylua
      dmsPackage
    ];
    backup = true;
  };
}
