{ ... }:

# 请根据实际情况修改，这是木泠的私人配置，不可直接使用。

{
  programs.git = {
    enable = true;
    settings = {
      user = {
        name = "Mooling0602";
        email = "clemooling@outlook.com";
        signingkey = "/home/mooling/.ssh/key-mooling-laptop.pub";
      };
      push = {
        autoSetupRemote = true;
      };
      pull = {
        rebase = true;
      };
      commit = {
        gpgsign = true;
      };
      gpg = {
        format = "ssh";
        ssh = {
          allowedSignersFile = "~/.config/git/allowed_signers";
        };
      };
      safe = {
        directory = "*";
      };
      init = {
        defaultBranch = "main";
      };
    };
  };
}
