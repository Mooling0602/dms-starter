{ ... }:

{
  services.gnome.gnome-keyring.enable = true;

  xdg.portal.config.common."org.freedesktop.impl.portal.Secret" = [ "gnome-keyring" ];
}
