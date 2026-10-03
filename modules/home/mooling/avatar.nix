{ username, ... }:

# Home-manager user space module, using by user mooling.

{
  home.file.".face".source = ../../../assets/${username}/avatar.jpg;
  home.file.".face.icon".source = ../../../assets/${username}/avatar.jpg;
}
