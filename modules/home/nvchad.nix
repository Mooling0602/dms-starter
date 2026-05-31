{ pkgs, config, lib, ... }:

let
  dmsThemeConfig = ''
    -- Load DMS colorscheme after all plugins are ready
    vim.api.nvim_create_autocmd("User", {
      pattern = "LazyDone",
      once = true,
      callback = function()
        vim.schedule(function()
          local ok, _ = pcall(vim.cmd.colorscheme, "dms")
          if not ok then
            vim.notify("DMS theme not found, run dms setup", vim.log.levels.WARN)
          end
        end)
      end,
    })
  '';
in
{
  programs.nvchad = {
    enable = true;
    extraPackages = with pkgs; [
      nixd
      lua-language-server
      bash-language-server
      python3Packages.python-lsp-server
    ];
    extraPlugins = ''
      return {
        {
          "Mooling0602/base46",
          branch = "v3.0",
          lazy = true,
        },
      }
    '';
    extraConfig = dmsThemeConfig;
    backup = true;
  };

  home.activation.dmsNvimColors = lib.hm.dag.entryAfter [ "writeBoundary" ] ''
    nvim_colors="${config.xdg.configHome}/nvim/colors"
    nvim_lualine="${config.xdg.configHome}/nvim/lua/lualine/themes"
    $DRY_RUN_CMD mkdir -p "$nvim_colors" "$nvim_lualine"
    if systemctl --user -q is-active dms.service 2>/dev/null; then
      $DRY_RUN_CMD systemctl --user restart dms.service
    fi
  '';
}
