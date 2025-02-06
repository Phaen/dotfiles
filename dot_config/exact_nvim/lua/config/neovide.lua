if vim.g.neovide then
  -- Use left option key on Macs as alt key
  -- NOTE: Make sure to disable conflicting Mac shortcuts in System Preferences > Keyboard > Shortcuts
  vim.g.neovide_input_macos_option_key_is_meta = "only_left"

  vim.g.remember_window_size = true
  vim.g.remember_window_position = true
  vim.g.neovide_refresh_rate = 60
  vim.g.neovide_fullscreen = false
  vim.g.neovide_profiler = false

  vim.g.neovide_transparency = 1
  vim.g.neovide_cursor_animate_in_insert_mode = true
  vim.g.neovide_cursor_vfx_mode = "wireframe" -- Available: railgun, torpedo, pixiedust, sonicboom, ripple, wireframe
  vim.g.neovide_hide_mouse_when_typing = true

  -- Zoom in and out with <c-+> and <c-->

  local default_scale = 0.8
  local scale_step = 1.1

  vim.g.neovide_scale_factor = default_scale
  local change_scale_factor = function(delta)
    vim.g.neovide_scale_factor = vim.g.neovide_scale_factor * delta
  end
  vim.keymap.set("n", "<C-=>", function()
    change_scale_factor(scale_step)
  end)
  vim.keymap.set("n", "<C-->", function()
    change_scale_factor(1 / scale_step)
  end)
  vim.keymap.set("n", "<C-0>", function()
    vim.g.neovide_scale_factor = default_scale
  end)

  local function toggle_transparency()
    if vim.g.neovide_transparency == 1.0 then
      vim.cmd("let g:neovide_transparency=0.8")
    else
      vim.cmd("let g:neovide_transparency=1.0")
    end
  end
  vim.keymap.set("n", "<leader>uv", toggle_transparency, { desc = "Toggle neovide transparency" })
end

-- Disable smooth scroll while switching buffers

local scroll_duration = 0.3
local cursor_duration = 0.08

vim.g.neovide_scroll_animation_length = scroll_duration
vim.g.neovide_cursor_animation_length = cursor_duration
vim.api.nvim_create_autocmd("BufLeave", {
  callback = function()
    vim.g.neovide_scroll_animation_length = 0
    vim.g.neovide_cursor_animation_length = 0
  end,
})
vim.api.nvim_create_autocmd("BufEnter", {
  callback = function()
    vim.fn.timer_start(70, function()
      vim.g.neovide_scroll_animation_length = scroll_duration
      vim.g.neovide_cursor_animation_length = cursor_duration
    end)
  end,
})
