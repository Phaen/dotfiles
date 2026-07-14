-- Keymaps are automatically loaded on the VeryLazy event
-- Default keymaps that are always set: https://github.com/LazyVim/LazyVim/blob/main/lua/lazyvim/config/keymaps.lua
-- Add any additional keymaps here
--
local map = vim.keymap.set
local unmap = vim.keymap.del

map("n", "<C-q>", "<cmd>q<cr>", { desc = "Quit", remap = true })

-- Deleting the last buffer leaves an empty [No Name] buffer; land on the
-- dashboard instead. Delete first, then reopen once the window has settled on
-- its replacement buffer (scheduling avoids racing Snacks.bufdelete).
local function delete_buffer_to_dashboard()
  Snacks.bufdelete()
  vim.schedule(function()
    local buf = vim.api.nvim_get_current_buf()
    local win = vim.api.nvim_get_current_win()
    if vim.api.nvim_buf_get_name(buf) == "" and vim.bo[buf].filetype == "" and not vim.bo[buf].modified then
      require("snacks.dashboard").open({ buf = buf, win = win })
    end
  end)
end

map("n", "<leader>bd", delete_buffer_to_dashboard, { desc = "Delete Buffer (or Dashboard)" })
