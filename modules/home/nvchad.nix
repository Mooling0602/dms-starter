{ pkgs, config, lib, dms, ... }:

let
  dmsThemeConfig = ''
    -- Load DMS colorscheme after all plugins are ready
    vim.api.nvim_create_autocmd("User", {
      pattern = "LazyDone",
      once = true,
      callback = function()
        vim.schedule(function()
          local mode = vim.fn.system({ "dms", "ipc", "call", "theme", "getMode" }):gsub("%s+", "")
          vim.notify(string.format("DMS mode: %s | bg before: %s | base46 transparency: %s",
            mode, vim.o.background, tostring(require("base46").opts.transparency)),
            vim.log.levels.INFO, { title = "DMS debug" })
          local ok, _ = pcall(vim.cmd.colorscheme, "dms")
          if ok then
            local hl = vim.api.nvim_get_hl(0, { name = "Normal" })
            vim.notify(string.format("Loaded dms | bg after: %s | Normal bg: %s",
              vim.o.background, tostring(hl.bg)),
              vim.log.levels.INFO, { title = "DMS debug" })
          else
            vim.notify("DMS theme not found, run dms setup", vim.log.levels.WARN)
          end
        end)
      end,
    })
  '';

  chadrc = ''
    local M = {}
    M.base46 = {
      transparency = true,
    }
    return M
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
      dms.packages.${pkgs.stdenv.hostPlatform.system}.default
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
    chadrcConfig = chadrc;
    backup = true;
  };

  home.activation.dmsNvimColors = lib.hm.dag.entryAfter [ "writeBoundary" ] ''
    nvim_colors="${config.xdg.configHome}/nvim/colors"
    nvim_lualine="${config.xdg.configHome}/nvim/lua/lualine/themes"
    $DRY_RUN_CMD mkdir -p "$nvim_colors" "$nvim_lualine"

    # Restore DMS-generated theme from newest backup
    latest_bak=$(ls -dt ${config.xdg.configHome}/nvim_*.bak 2>/dev/null | head -1)
    if [ -n "$latest_bak" ] && [ -f "$latest_bak/colors/dms.lua" ]; then
      $DRY_RUN_CMD cp "$latest_bak/colors/dms.lua" "$nvim_colors/dms.lua"
    fi
    if [ -n "$latest_bak" ] && [ -f "$latest_bak/lua/lualine/themes/dms.lua" ]; then
      $DRY_RUN_CMD cp "$latest_bak/lua/lualine/themes/dms.lua" "$nvim_lualine/dms.lua"
    fi
  '';
}
