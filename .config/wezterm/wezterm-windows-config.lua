-- Pull in the wezterm API
local wezterm = require 'wezterm'
local act = wezterm.action

-- This will hold the configuration.
local config = wezterm.config_builder()

-- Cursor
config.cursor_blink_rate = 500 -- milliseconds
-- Blinking cursor
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

-- Windows PowerShell 5.1 exact colors
local powershell_classic = {
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
}

-- Per-profile color themes based on foreground process
wezterm.on('update-status', function(window, pane)
  local process = pane:get_foreground_process_name() or ''
  local p = process:lower()

  if p:find('pwsh') then
    -- PowerShell 7 → Catppuccin Mocha
    window:set_config_overrides({ color_scheme = 'Catppuccin Mocha (Gogh)' })
  -- elseif p:find('powershell') then
  --   -- Windows PowerShell → classic blue look
  --   window:set_config_overrides({ color_scheme = 'Cobalt2' })
  elseif p:find('powershell') then
    -- Windows PowerShell 5.1 exact colors
    window:set_config_overrides({
      colors = powershell_classic,
    })
  elseif p:find('wsl') or p:find('bash') or p:find('debian') or p:find('ubuntu') then
    -- WSL → Ubuntu colors
    window:set_config_overrides({ color_scheme = 'Ubuntu' })
  else
    -- CMD / anything else → Catppuccin Mocha
    window:set_config_overrides({ color_scheme = 'Catppuccin Mocha (Gogh)' })
  end
end)

-- Finally, return the configuration to wezterm:
return config
