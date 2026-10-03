{ username, hostname, ... }:

let
  optionalImports = import ../../utils/optional_import.nix;
in
{
  # 桌面相关模块不在这里导入：Home Manager 层的桌面实现由当前桌面层通过
  # home-manager.sharedModules 挂进来（见 modules/desktop/<name>/system.nix）。
  # 这里只保留与桌面无关的通用配置。
  imports = optionalImports [
    ./defaults/packages.nix
    ./defaults/theme.nix
    ./defaults/ssh.nix
    ./defaults/nvchad.nix
    ./defaults/wine.nix
    ./defaults/terminal.nix
    ./defaults/file-manager.nix
    ./${username}/default.nix
    ./${username}/git.nix
    ./${username}/packages.nix
    ./${username}/avatar.nix
    ../../hosts/${hostname}/users/${username}.nix
  ];

  home.username = username;
  home.homeDirectory = "/home/${username}";
  home.stateVersion = "25.11";
}
