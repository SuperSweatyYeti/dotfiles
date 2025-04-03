
local wezterm = require 'wezterm'
-- local commands = require 'commands'
local config = wezterm.config_builder()

--
-- Appearance
--
-- Colorscheme
-- config.color_scheme = 'Catppuccin Mocha (Gogh)'
-- config.color_scheme = 'Catppuccin Macchiato'
-- config.color_scheme = 'Catppuccin Macchiato (Gogh)'
-- config.color_scheme = 'Chalkboard (Gogh)'
-- config.color_scheme = 'Tokyo Night'
-- config.color_scheme = 'Tokyo Night Moon'
-- config.color_scheme = 'Tomorrow (dark) (terminal.sexy)'
config.color_scheme = 'Gruvbox Dark (Gogh)'
config.window_background_opacity = 1.0 -- Max 1.0 Min 0.0
-- Only for Macos ?
-- config.macos_window_background_blur = 20 -- Max 20 Min 0
-- Font settings
config.font_size = 15
-- config.line_height = 1.2
config.font = wezterm.font {
  family = 'DejaVuSansM Nerd Font mono',
  harfbuzz_features = {
    'calt',
    'ss01',
    'ss02',
    'ss03',
    'ss04',
    'ss05',
    'ss06',
    'ss07',
    'ss08',
    'ss09',
    'liga',
  },
}
config.font_rules = {
  {
    -- italic = true,
    font = wezterm.font('DejaVuSansM Nerd Font mono', {
      -- italic = true,
    }),
  },
}

-- Cursor
config.default_cursor_style = 'BlinkingBlock'
-- Blink rate in ms
config.cursor_blink_rate = 500
-- cursor_blink_ease_in = "Linear"
config.cursor_blink_ease_in = "Constant"
config.cursor_blink_ease_out = "Constant"

config.hide_tab_bar_if_only_one_tab = true
config.window_padding = {
  left = 0,
  right = 0,
  top = 0,
  bottom = 0,
}


-- Behavior
-- Don't prompt for confirmation when closing window
config.window_close_confirmation = 'NeverPrompt'
-- Enable scrollbar
config.enable_scroll_bar = true

-- Miscellaneous settings
config.max_fps = 120
config.prefer_egl = true

-- Custom commands

return config
