{ pkgs, config, lib, dms, ... }:

let
  dmsThemeConfig = ''
    local function load_dms_theme()
      local mode = vim.fn.system({ "dms", "ipc", "call", "theme", "getMode" }):gsub("%s+", "")
      local base46 = require("base46")
      local chadrc_ok, chadrc = pcall(require, "chadrc")
      local nvcfg_ok, nvcfg = pcall(require, "nvconfig")
      vim.print("--- DMS debug ---")
      vim.print("DMS mode: " .. mode)
      vim.print("bg before: " .. vim.o.background)
      vim.print("base46 opts.transparency: " .. tostring(base46.opts.transparency))
      if chadrc_ok and chadrc.base46 then
        vim.print("chadrc base46.transparency: " .. tostring(chadrc.base46.transparency))
      else
        vim.print("chadrc: " .. (chadrc_ok and "loaded but no base46" or "not found"))
      end
      if nvcfg_ok and nvcfg.base46 then
        vim.print("nvconfig base46.transparency: " .. tostring(nvcfg.base46.transparency))
      else
        vim.print("nvconfig: " .. (nvcfg_ok and "loaded but no base46" or "not found"))
      end
      local ok, _ = pcall(vim.cmd.colorscheme, "dms")
      if ok then
        local hl = vim.api.nvim_get_hl(0, { name = "Normal" })
        vim.print("loaded dms ok: bg=" .. vim.o.background .. " Normal.bg=" .. tostring(hl.bg))
      else
        vim.print("ERROR: DMS theme not found, run dms setup")
      end
      vim.print("---")
    end

    -- Defer to let lazy.nvim finish loading plugins
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
