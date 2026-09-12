{ ... }:

# 请根据实际情况修改，这里只是一个模板

{
  programs.git = {
    enable = true;
    settings = {
      user = {
        name = "NixOS_User";
        email = "nixos_user@users.noreply.github.com";
        # signingkey = "~/.ssh/id_25519.pub";
      };
      push = {
        autoSetupRemote = true;
      };
      # pull = {
      #   rebase = true;
      # };
      # commit = {
      #   gpgsign = true;
      # };
      # gpg = {
      #   format = "ssh";
      #   ssh = {
      #     allowedSignersFile = "~/.config/git/allowed_signers";
      #   };
      # };
      # safe = {
      #   directory = "*";
      # };
      init = {
        defaultBranch = "main";
      };
    };
  };
}
