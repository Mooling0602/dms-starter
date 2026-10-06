# Home-manager user space module, using by user mooling.
#
# Edit this for your own setup; this is Mooling's personal configuration and is
# not meant to be used as is.

{
  programs.git = {
    enable = true;
    settings = {
      user = {
        name = "Mooling0602";
        email = "clemooling@outlook.com";
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
