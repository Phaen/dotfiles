---@type LazyPluginSpec
return {
  { "EdenEast/nightfox.nvim" },

  { "catppuccin/nvim", name = "catppuccin", priority = 1000 },

  {
    "LazyVim/LazyVim",
    opts = {
      colorscheme = "catppuccin-mocha",
    },
  },
}
