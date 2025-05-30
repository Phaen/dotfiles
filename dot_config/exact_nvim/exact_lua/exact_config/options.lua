-- Options are automatically loaded before lazy.nvim startup
-- Default options that are always set: https://github.com/LazyVim/LazyVim/blob/main/lua/lazyvim/config/options.lua
-- Add any additional options here

-- Remove eyestrain
vim.api.nvim_set_hl(0, "DiffDelete", {
  bg = vim.api.nvim_get_hl(0, { name = "CursorColumn" }).bg,
  fg = vim.api.nvim_get_hl(0, { name = "Cursor" }).fg,
})

-- Enable dynamic window titles (otherwise just shows app name)
vim.opt.title = true

-- Set proper font to use
vim.opt.guifont = "FiraCode\\ Nerd\\ Font"

-- Increase PHPStan memory limit, otherwise it will crash on large projects
vim.env.PHPSTAN_MEMORY_LIMIT = "1G"

-- Base the working directory on the root of the project
vim.g.root_spec = { "cwd" }

require("config.neovide")
