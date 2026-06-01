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

    -- Debug logging to file (readable by Claude)
    local logfile = vim.fn.stdpath("cache") .. "/tabline-debug.log"
    local function dlog(msg)
      local f = io.open(logfile, "a")
      if f then
        f:write(string.format("[%s] %s\n", os.date("%H:%M:%S"), msg))
        f:close()
      end
    end
    -- Clear log on startup
    local f = io.open(logfile, "w")
    if f then f:write("=== tabline debug log ===\n") f:close() end

    local function fix_tabline_colors()
      local base46 = require("base46")
      local theme = base46.theme_tables["dms"]
      if not theme then
        dlog("fix_tabline_colors: theme_tables['dms'] is nil")
        return
      end
      local c = theme.base_30
      dlog(string.format("fix_tabline_colors: black=%s black2=%s white=%s", c.black, c.black2, c.white))

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

      -- Verify what was actually set
      local tf = vim.api.nvim_get_hl(0, { name = "TbFill" })
      local tbo = vim.api.nvim_get_hl(0, { name = "TbBufOn" })
      dlog(string.format("fix_tabline_colors DONE: TbFill.bg=%s TbBufOn.bg=%s",
        tostring(tf.bg), tostring(tbo.bg)))
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

    -- Debug command: dump current tabline state to log file
    local function tabline_debug()
      local groups = { "Tabline", "TbFill", "TbBufOn", "TbBufOff", "Normal" }
      dlog("--- TablineDebug command ---")
      for _, g in ipairs(groups) do
        local hl = vim.api.nvim_get_hl(0, { name = g })
        dlog(string.format("%s: fg=%s bg=%s", g, tostring(hl.fg), tostring(hl.bg)))
      end
      local base46 = require("base46")
      local theme = base46.theme_tables["dms"]
      if theme then
        local c = theme.base_30
        dlog(string.format("dms base_30: black=%s black2=%s", c.black, c.black2))
      else
        dlog("dms theme_tables not found")
      end
      dlog("showtabline=" .. vim.o.showtabline)
      dlog("--- end TablineDebug ---")
      vim.notify("TablineDebug written to " .. logfile, vim.log.levels.INFO)
    end
    vim.api.nvim_create_user_command("TablineDebug", tabline_debug, {})

    local function load_dms_theme()
      local base46 = require("base46")
      dlog("load_dms_theme: starting")

      local nvcfg_ok, nvcfg = pcall(require, "nvconfig")
      if nvcfg_ok and nvcfg.base46 then
        base46.setup(nvcfg.base46)
      end

      pcall(vim.cmd.colorscheme, "dms")
      dlog("load_dms_theme: colorscheme dms applied, current_theme=" .. tostring(base46.current_theme))

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

    -- Fix tabline: when tabufline lazy-load activates, re-apply base46's tbline
    -- integration (which properly applies hl_override + transparency) to overwrite
    -- the stale cached colors loaded by dofile("tbline").
    vim.api.nvim_create_autocmd("OptionSet", {
      pattern = "showtabline",
      callback = function()
        dlog(string.format("OptionSet showtabline fired, value=%d", vim.o.showtabline))
        if vim.o.showtabline == 2 then
          vim.defer_fn(function()
            local base46 = require("base46")
            local has_dms = base46.theme_tables["dms"] ~= nil
            dlog("OptionSet 300ms defer: has_dms=" .. tostring(has_dms))
            if not has_dms then return end
            local highlights = base46.get_integration("tbline")
            dlog("OptionSet: get_integration tbline=" .. tostring(highlights ~= nil))
            if highlights then
              for hlname, hlopts in pairs(highlights) do
                vim.api.nvim_set_hl(0, hlname, hlopts)
              end
              local tf = vim.api.nvim_get_hl(0, { name = "TbFill" })
              dlog("OptionSet after integration: TbFill.bg=" .. tostring(tf.bg))
            end
          end, 300)
        end
      end,
    })

    -- Fix tabline: runs on ColorScheme change (manual :colorscheme dms).
    vim.api.nvim_create_autocmd("ColorScheme", {
      pattern = "dms",
      callback = function() vim.defer_fn(fix_tabline_colors, 100) end,
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
