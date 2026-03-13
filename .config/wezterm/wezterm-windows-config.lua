-- Pull in the wezterm API
local wezterm = require 'wezterm'
local act = wezterm.action

-- This will hold the configuration.
local config = wezterm.config_builder()


config.window_padding = {
  left = '1cell',
  right = '1cell',
  top = '0.2cell',
  bottom = '0.2cell',
}

-- Scrolling
-- Enable the scrollbar.
-- It will occupy the right window padding space.
-- If right padding is set to 0 then it will be increased
-- to a single cell width
config.enable_scroll_bar = true
-- How many lines of scrollback you want to retain per tab
config.scrollback_lines = 50000


-- Cursor
config.cursor_blink_rate = 500 -- milliseconds
config.default_cursor_style = 'SteadyBlock'

-- Initial geometry
config.initial_cols = 120
config.initial_rows = 28

-- Enable kitty graphics protocol (on by default, but explicit is fine)
config.enable_kitty_graphics = true

-- Font and color scheme (default → PowerShell 7)
config.font = wezterm.font 'Hack Nerd Font'
config.font_size = 13
config.color_scheme = 'Catppuccin Mocha (Gogh)'
config.colors = {
  scrollbar_thumb = '#9b9b9b',
}

-- Windows PowerShell 5.1 exact colors
local powershell_classic = {
  scrollbar_thumb = '#9b9b9b',
  background = '#012456',
  foreground = '#EEEDF0',
  cursor_bg = '#EEEDF0',
  cursor_fg = '#012456',
  cursor_border = '#EEEDF0',
  selection_bg = '#EEEDF0',
  selection_fg = '#012456',
  ansi = {
    '#012456', -- black
    '#C50F1F', -- red
    '#13A10E', -- green
    '#C19C00', -- yellow
    '#0037DA', -- blue
    '#881798', -- magenta
    '#3A96DD', -- cyan
    '#CCCCCC', -- white
  },
  brights = {
    '#767676', -- bright black
    '#E74856', -- bright red
    '#16C60C', -- bright green
    '#F9F1A5', -- bright yellow
    '#3B78FF', -- bright blue
    '#B4009E', -- bright magenta
    '#61D6D6', -- bright cyan
    '#F2F2F2', -- bright white
  },
}

-- Default shell → PowerShell 7
config.default_prog = { 'C:\\Program Files\\PowerShell\\7\\pwsh.exe' }

-- Launch menu (Ctrl+Shift+Space to open)
config.launch_menu = {
  {
    label = 'PowerShell',
    args = { 'C:\\Program Files\\PowerShell\\7\\pwsh.exe' },
  },
  {
    label = 'Windows PowerShell',
    args = { 'C:\\Windows\\System32\\WindowsPowerShell\\v1.0\\powershell.exe' },
  },
  {
    label = 'CMD',
    args = { 'C:\\Windows\\System32\\cmd.exe' },
  },
  {
    label = 'WSL - Debian',
    args = { 'wsl.exe', '-d', 'Debian' },
  }
}

config.disable_default_key_bindings = true

config.keys = {

  -- Re-add essential default bindings
  { key = 'c',     mods = 'CTRL|SHIFT', action = act.CopyTo 'Clipboard' },
  { key = 'v',     mods = 'CTRL|SHIFT', action = act.PasteFrom 'Clipboard' },
  { key = 't',     mods = 'CTRL|SHIFT', action = act.SpawnTab 'CurrentPaneDomain' },
  { key = 'w',     mods = 'CTRL|SHIFT', action = act.CloseCurrentTab { confirm = true } },
  { key = 'Tab',   mods = 'CTRL',       action = act.ActivateTabRelative(1) },
  { key = 'Tab',   mods = 'CTRL|SHIFT', action = act.ActivateTabRelative(-1) },
  { key = 'Space', mods = 'CTRL|SHIFT', action = act.ShowLauncherArgs { flags = 'LAUNCH_MENU_ITEMS' } },
  { key = 'l',     mods = 'CTRL|SHIFT', action = act.ShowDebugOverlay },
  { key = 'f',     mods = 'CTRL|SHIFT', action = act.Search 'CurrentSelectionOrEmptyString' },
  { key = 'Enter', mods = 'ALT',        action = act.ToggleFullScreen },
  { key = '+',     mods = 'CTRL',       action = act.IncreaseFontSize },
  { key = '-',     mods = 'CTRL',       action = act.DecreaseFontSize },
  { key = '0',     mods = 'CTRL',       action = act.ResetFontSize },

  -- Ctrl+Shift+1 → PowerShell 7
  {
    key = 'phys:1',
    mods = 'CTRL|SHIFT',
    action = act.SpawnCommandInNewTab {
      args = { 'C:\\Program Files\\PowerShell\\7\\pwsh.exe' },
    },
  },

  -- Ctrl+Shift+2 → Windows PowerShell
  {
    key = 'phys:2',
    mods = 'CTRL|SHIFT',
    action = act.SpawnCommandInNewTab {
      args = { 'C:\\Windows\\System32\\WindowsPowerShell\\v1.0\\powershell.exe' },
    },
  },

  -- Ctrl+Shift+3 → CMD
  {
    key = 'phys:3',
    mods = 'CTRL|SHIFT',
    action = act.SpawnCommandInNewTab {
      args = { 'cmd.exe' },
    },
  },

  -- Ctrl+Shift+4 → WSL Debian
  {
    key = 'phys:4',
    mods = 'CTRL|SHIFT',
    action = act.SpawnCommandInNewTab {
      args = { 'wsl.exe', '-d', 'Debian' },
    },
  },

  -- Split panes
  { key = 'd', mods = 'CTRL|SHIFT', action = act.SplitHorizontal { domain = 'CurrentPaneDomain' } },
  { key = 'e', mods = 'CTRL|SHIFT', action = act.SplitVertical   { domain = 'CurrentPaneDomain' } },

  -- Move between panes
  { key = 'LeftArrow',  mods = 'CTRL|SHIFT', action = act.ActivatePaneDirection 'Left'  },
  { key = 'RightArrow', mods = 'CTRL|SHIFT', action = act.ActivatePaneDirection 'Right' },
  { key = 'UpArrow',    mods = 'CTRL|SHIFT', action = act.ActivatePaneDirection 'Up'    },
  { key = 'DownArrow',  mods = 'CTRL|SHIFT', action = act.ActivatePaneDirection 'Down'  },

  -- Cycle between tabs
  { key = '{', mods = 'CTRL|SHIFT', action = act.ActivateTabRelative(1)  },
  { key = '}', mods = 'CTRL|SHIFT', action = act.ActivateTabRelative(-1) },

  -- Close current pane
  { key = 'x', mods = 'CTRL|SHIFT', action = act.CloseCurrentPane { confirm = true } },

  -- Pane launcher (separate from tab launcher) → Alt+Shift+Space
  { key = 'Space', mods = 'ALT|SHIFT', action = act.ShowLauncherArgs { flags = 'TABS' } },
}

-- Per-tab color scheme, detected ONCE on first update, reapplied on every update
local tab_schemes = {}

wezterm.on('update-status', function(window, pane)
  local tab_id = tostring(window:active_tab():tab_id())

  -- Only detect the scheme if we haven't seen this tab before
  if not tab_schemes[tab_id] then
    local process = pane:get_foreground_process_name() or ''
    local p = process:lower()

    local root = ''
    local procs = pane:get_foreground_process_info()
    if procs then
      root = (procs.name or ''):lower()
    end

    -- Only store if we actually got a process, otherwise wait for next update
    if p ~= '' or root ~= '' then
      if p:find('pwsh') or root:find('pwsh') then
        tab_schemes[tab_id] = 'pwsh'
      elseif (p:find('powershell') or root:find('powershell')) and not p:find('pwsh') then
        tab_schemes[tab_id] = 'powershell'
      elseif root:find('wsl') then
        tab_schemes[tab_id] = 'wsl'
      elseif p:find('cmd') or root:find('cmd') then
        tab_schemes[tab_id] = 'cmd'
      else
        tab_schemes[tab_id] = 'default'
      end
    end
  end

  -- Always reapply the stored scheme for this tab
  local scheme = tab_schemes[tab_id]
  if scheme == 'pwsh' then
    window:set_config_overrides({ color_scheme = 'Catppuccin Mocha (Gogh)', colors = { scrollbar_thumb = '#9b9b9b' } })
  elseif scheme == 'powershell' then
    window:set_config_overrides({ colors = powershell_classic })
  elseif scheme == 'wsl' then
    window:set_config_overrides({ color_scheme = 'Ubuntu', colors = { scrollbar_thumb = '#9b9b9b' } })
  elseif scheme == 'cmd' then
    window:set_config_overrides({ color_scheme = 'Campbell (Windows Terminal)', colors = { scrollbar_thumb = '#9b9b9b' } })
  else
    window:set_config_overrides({ color_scheme = 'Catppuccin Mocha (Gogh)', colors = { scrollbar_thumb = '#9b9b9b' } })
  end
end)

-- Finally, return the configuration to wezterm:
return config
