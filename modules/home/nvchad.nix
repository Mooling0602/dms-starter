{ pkgs, ... }:

{
  programs.nvchad = {
    enable = true;
    extraPackages = with pkgs; [
      nixd
      lua-language-server
      nodePackages.bash-language-server
      python3Packages.python-lsp-server
    ];
    backup = true;
  };
}
