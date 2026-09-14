{ pkgs, ... }:

{
  # Refers to https://wiki.nixos.org/wiki/OBS_Studio
  programs.obs-studio = {
    enable = true;
    plugins = with pkgs.obs-studio-plugins; [
      wlrobs
      obs-pipewire-audio-capture
      obs-source-record
      obs-vkcapture
    ];
  };
}
