{ pkgs, config, lib, dms, ... }:

let
  dmsThemeConfig = ''
    local function load_dms_theme()
      local base46 = require("base46")

      -- Sync settings from nvconfig (includes chadrc overrides) into base46
      -- nvconfig isn't available when load_all_highlights first runs during
      -- plugin build, so we need to manually apply the settings here.
      local nvcfg_ok, nvcfg = pcall(require, "nvconfig")
      if nvcfg_ok and nvcfg.base46 then
        base46.setup(nvcfg.base46)
      end

      local mode = vim.fn.system({ "dms", "ipc", "call", "theme", "getMode" }):gsub("%s+", "")
      vim.print("--- DMS debug ---")
      vim.print("DMS mode: " .. mode)
      vim.print("bg before: " .. vim.o.background)
      vim.print("transparency after sync: " .. tostring(base46.opts.transparency))
      local ok, _ = pcall(vim.cmd.colorscheme, "dms")
      if ok then
        local hl = vim.api.nvim_get_hl(0, { name = "Normal" })
        vim.print("loaded dms: bg=" .. vim.o.background .. " Normal.bg=" .. tostring(hl.bg))
      else
        vim.print("ERROR: DMS theme not found")
      end
      vim.print("---")
    end

    vim.defer_fn(load_dms_theme, 1000)
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
