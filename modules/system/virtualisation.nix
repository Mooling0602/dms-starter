{ config, pkgs, ... }:

{
  virtualisation.libvirtd = {
    enable = true;
    qemu.swtpm.enable = true;
    qemu.ovmf.enable = true;
  };

  programs.virt-manager.enable = true;

  users.users.${config.my.username}.extraGroups = [ "libvirtd" ];

  environment.systemPackages = with pkgs; [
    virt-viewer
    spice-gtk
  ];
}
