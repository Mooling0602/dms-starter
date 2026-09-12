{ username, ... }:

{
  home.file.".face".source = ../../../assets/${username}/avatar.jpg;
  home.file.".face.icon".source = ../../../assets/${username}/avatar.jpg;
}
