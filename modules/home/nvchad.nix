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

    local function fix_popup_colors()
      local base46 = require("base46")
      local theme = base46.theme_tables["dms"]
      if not theme then return end
      local c = theme.base_30

      -- Floating window borders
      vim.api.nvim_set_hl(0, "FloatBorder",           { fg = c.line, bg = "NONE" })
      vim.api.nvim_set_hl(0, "TelescopeBorder",       { fg = c.line, bg = "NONE" })
      vim.api.nvim_set_hl(0, "TelescopePromptBorder", { fg = c.line, bg = "NONE" })
      vim.api.nvim_set_hl(0, "TelescopeResultsBorder",{ fg = c.line, bg = "NONE" })
      vim.api.nvim_set_hl(0, "CmpDocBorder",          { fg = c.line, bg = "NONE" })
      vim.api.nvim_set_hl(0, "BlinkCmpDocBorder",     { fg = c.line, bg = "NONE" })
      vim.api.nvim_set_hl(0, "BlinkCmpMenuBorder",    { fg = c.line, bg = "NONE" })
      vim.api.nvim_set_hl(0, "NotifyBorder",          { fg = c.line, bg = "NONE" })
      vim.api.nvim_set_hl(0, "NormalFloat", { bg = c.black })
    end

    local function fix_tabline_colors()
      local base46 = require("base46")
      local theme = base46.theme_tables["dms"]
      if not theme then return end
      local c = theme.base_30

      -- NvChad tabufline uses "Tb" prefix: TbFill, TbBufOn, TbBufOff, etc.
      vim.api.nvim_set_hl(0, "TbFill",              { bg = c.black2 })
      vim.api.nvim_set_hl(0, "TbBufOn",             { fg = c.white, bg = c.black })
      vim.api.nvim_set_hl(0, "TbBufOff",            { fg = c.light_grey, bg = c.black2 })
      vim.api.nvim_set_hl(0, "TbBufOnClose",        { fg = c.red, bg = c.black })
      vim.api.nvim_set_hl(0, "TbBufOffClose",       { fg = c.grey_fg, bg = c.black2 })
      vim.api.nvim_set_hl(0, "TbBufOnModified",     { fg = c.green, bg = c.black })
      vim.api.nvim_set_hl(0, "TbBufOffModified",    { fg = c.red, bg = c.black2 })
      vim.api.nvim_set_hl(0, "TbTabOn",             { fg = c.red, bg = c.black })
      vim.api.nvim_set_hl(0, "TbTabOff",            { fg = c.light_grey, bg = c.black2 })
      vim.api.nvim_set_hl(0, "TbTabNewBtn",         { fg = c.light_grey, bg = c.one_bg })
      vim.api.nvim_set_hl(0, "TbThemeToggleBtn",    { fg = c.light_grey, bg = c.one_bg2 })
      vim.api.nvim_set_hl(0, "TbCloseAllBufsBtn",   { fg = c.black, bg = c.red })
    end

    local function fix_nvimtree_colors()
      local base46 = require("base46")
      local theme = base46.theme_tables["dms"]
      if not theme then return end
      local c = theme.base_30

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
    end

    local function load_dms_theme()
      local base46 = require("base46")

      local nvcfg_ok, nvcfg = pcall(require, "nvconfig")
      if nvcfg_ok and nvcfg.base46 then
        base46.setup(nvcfg.base46)
      end

      pcall(vim.cmd.colorscheme, "dms")

      -- Fix popup borders/backgrounds immediately after theme loads
      vim.defer_fn(fix_popup_colors, 100)
    end

    -- Load DMS theme after startup delay
    vim.defer_fn(load_dms_theme, 1000)

    -- Fix nvim-tree: runs AFTER nvim-tree lazy-loads (it overwrites our hl)
    vim.api.nvim_create_autocmd("FileType", {
      pattern = "NvimTree",
      once = true,
      callback = function()
        vim.defer_fn(fix_nvimtree_colors, 100)
      end,
    })

    -- Fix tabline: runs on ColorScheme change OR BufEnter (tabufline lazyload).
    -- vim.schedule defers to end of event loop, after NvChad's own handlers + dofile.
    local function apply_tabline_fix()
      local base46 = require("base46")
      if not base46.theme_tables["dms"] then return end
      vim.schedule(fix_tabline_colors)
    end
    vim.api.nvim_create_autocmd("ColorScheme", {
      pattern = "dms",
      callback = function() vim.defer_fn(apply_tabline_fix, 100) end,
    })
    vim.api.nvim_create_autocmd("BufEnter", {
      callback = apply_tabline_fix,
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
        -- Tabline background follows theme
        TbFill = { bg = "black2" },
        TbBufOn = { fg = "white", bg = "black" },
        TbBufOff = { fg = "light_grey", bg = "black2" },
        TbBufOnClose = { fg = "red", bg = "black" },
        TbBufOffClose = { fg = "grey_fg", bg = "black2" },
        TbBufOnModified = { fg = "green", bg = "black" },
        TbBufOffModified = { fg = "red", bg = "black2" },
        TbTabOn = { fg = "red", bg = "black" },
        TbTabOff = { fg = "light_grey", bg = "black2" },
        TbTabNewBtn = { fg = "light_grey", bg = "one_bg" },
        TbThemeToggleBtn = { fg = "light_grey", bg = "one_bg2" },
        TbCloseAllBufsBtn = { fg = "black", bg = "red" },
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
