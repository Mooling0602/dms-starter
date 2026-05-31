{ pkgs, config, lib, dms, ... }:

let
  dmsThemeConfig = ''
    local function dms_debug()
      local base46 = require("base46")
      local mode = vim.fn.system({ "dms", "ipc", "call", "theme", "getMode" }):gsub("%s+", "")
      local dms_ok = vim.fn.filereadable(vim.fn.stdpath("config") .. "/colors/dms.lua") == 1
      local hl = vim.api.nvim_get_hl(0, { name = "Normal" })
      vim.print("--- DMS debug ---")
      vim.print("DMS mode:     " .. mode)
      vim.print("vim.o.bg:     " .. vim.o.background)
      vim.print("colors_name:  " .. (vim.g.colors_name or "nil"))
      vim.print("transparency: " .. tostring(base46.opts.transparency))
      vim.print("dms.lua:      " .. (dms_ok and "found" or "missing"))
      vim.print("Normal.bg:    " .. tostring(hl.bg))
      vim.print("---")
    end
    vim.api.nvim_create_user_command("DmsDebug", dms_debug, {})

    local function fix_ui_colors()
      local base46 = require("base46")
      local theme = base46.theme_tables["dms"]
      if not theme then return end
      local c = theme.base_30

      -- NvimTree: solid background + readable colors
      vim.api.nvim_set_hl(0, "NvimTreeNormal",    { bg = c.black })
      vim.api.nvim_set_hl(0, "NvimTreeNormalNC",  { bg = c.black })
      vim.api.nvim_set_hl(0, "NvimTreeCursorLine", { bg = c.black2 })
      vim.api.nvim_set_hl(0, "NvimTreeEndOfBuffer", { fg = c.darker_black, bg = c.black })
      vim.api.nvim_set_hl(0, "NvimTreeWinSeparator", { fg = c.line, bg = c.darker_black })
      vim.api.nvim_set_hl(0, "NvimTreeFolderName", { fg = "#2e5a4c" })
      vim.api.nvim_set_hl(0, "NvimTreeFolderIcon", { fg = "#2e5a4c" })
      vim.api.nvim_set_hl(0, "NvimTreeEmptyFolderName", { fg = "#2e5a4c" })
      vim.api.nvim_set_hl(0, "NvimTreeRootFolder", { fg = "#1a6b5a", bold = true })
      vim.api.nvim_set_hl(0, "NvimTreeIndentMarker", { fg = c.one_bg3 })

      -- Floating window borders: visible divider between popups and editor
      vim.api.nvim_set_hl(0, "FloatBorder",           { fg = c.line, bg = "NONE" })
      vim.api.nvim_set_hl(0, "TelescopeBorder",       { fg = c.line, bg = "NONE" })
      vim.api.nvim_set_hl(0, "TelescopePromptBorder", { fg = c.line, bg = "NONE" })
      vim.api.nvim_set_hl(0, "TelescopeResultsBorder",{ fg = c.line, bg = "NONE" })
      vim.api.nvim_set_hl(0, "CmpDocBorder",          { fg = c.line, bg = "NONE" })
      vim.api.nvim_set_hl(0, "BlinkCmpDocBorder",     { fg = c.line, bg = "NONE" })
      vim.api.nvim_set_hl(0, "BlinkCmpMenuBorder",    { fg = c.line, bg = "NONE" })
      vim.api.nvim_set_hl(0, "NotifyBorder",          { fg = c.line, bg = "NONE" })
      vim.api.nvim_set_hl(0, "MasonNormal",           { bg = c.black })
    end

    local function load_dms_theme()
      local base46 = require("base46")

      -- Sync nvconfig settings (chadrc overrides) into base46.
      local nvcfg_ok, nvcfg = pcall(require, "nvconfig")
      if nvcfg_ok and nvcfg.base46 then
        base46.setup(nvcfg.base46)
      end

      pcall(vim.cmd.colorscheme, "dms")
    end

    -- Load DMS theme after startup delay
    vim.defer_fn(load_dms_theme, 1000)

    -- Fix nvim-tree colors: apply AFTER nvim-tree loads (it overwrites our hl)
    vim.api.nvim_create_autocmd("FileType", {
      pattern = "NvimTree",
      once = true,
      callback = function()
        vim.defer_fn(fix_ui_colors, 100)
      end,
    })
  '';

  chadrc = ''
    local M = {}
    M.base46 = {
      transparency = true,
      hl_override = {
        -- Solid background for file tree (transparency looks dark)
        NvimTreeNormal = { bg = "black" },
        NvimTreeNormalNC = { bg = "black" },
        NvimTreeCursorLine = { bg = "black2" },
        NvimTreeEndOfBuffer = { fg = "darker_black", bg = "black" },
        NvimTreeWinSeparator = { fg = "darker_black", bg = "darker_black" },
        -- Readable folder colors
        NvimTreeFolderName = { fg = "#2e5a4c" },
        NvimTreeFolderIcon = { fg = "#2e5a4c" },
        NvimTreeEmptyFolderName = { fg = "#2e5a4c" },
        NvimTreeRootFolder = { fg = "#1a6b5a", bold = true },
        NvimTreeIndentMarker = { fg = "#c2ddc8" },
      },
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
