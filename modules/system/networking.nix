{ ... }:

{
  networking.firewall.enable = false; # For normal users, firewall is not so useful and causes many errors

  networking.networkmanager.enable = true; # You need Internet!

  networking.hosts = {
    # Add your hosts config here
  };

  programs.clash-verge = {
    enable = true;
    serviceMode = true;
    tunMode = true;
  }; # Magical cat that can ignore GFW~
}
