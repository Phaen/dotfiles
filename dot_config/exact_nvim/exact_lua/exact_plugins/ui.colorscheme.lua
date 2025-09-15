---@type LazyPluginSpec
return {
  -- catppuccin theme
  {
    "catppuccin/nvim",
    version = "v1.11.0", -- the master branch changed 'get()' function,
    name = "catppuccin",
    -- lazy = true,
    priority = 1000,
    opts = {
      flavour = "mocha",
      transparent_background = vim.g.transparent_background,
      float = {
        transparent = vim.g.transparent_background, -- enable transparent floating windows
        solid = false, -- use solid styling for floating windows, see |winborder|
      },
    },
  },
  {
    "LazyVim/LazyVim",
    opts = {
      colorscheme = "catppuccin",
    },
  },
}
