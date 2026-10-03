{ ... }:

# Home-manager module, has been imported by default.

{
  # Use Dolphin as default file explorer
  xdg.mimeApps.defaultApplications = {
    "inode/directory" = [ "org.kde.dolphin.desktop" ];
  };
}
