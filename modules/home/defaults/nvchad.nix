{ pkgs, ... }:

{
  programs.nvchad = {
    enable = true;
    extraPackages = with pkgs; [
      nixd
      lua-language-server
      bash-language-server
      python3Packages.python-lsp-server
      stylua
    ];
    # nix4nvchad copies the store config into ~/.config/nvim on every
    # activation. Backing up first leaves one nvim_<timestamp>.bak per rebuild
    # (110 had accumulated); the config is fully declarative, so disable it.
    backup = false;
  };
}
