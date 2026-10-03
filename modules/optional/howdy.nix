{ ... }:

# system module, can be imported in host/<hostname>

{
  services.howdy = {
    enable = true;
    control = "sufficient";
    settings = {
      core = {
        abort_if_ssh = false;
        detection_notice = true;
      };
    };
  };

  # greetd delegates authentication to the login PAM stack. Face authentication
  # cannot provide the password needed to unlock GNOME Keyring.
  security.pam.services.greetd.howdy.enable = false;
  security.pam.services.login.howdy.enable = false;

  # polkit-1 is unhappy with howdy fails
  security.pam.services.polkit-1.howdy.enable = false;
}
