return {
  "esmuellert/codediff.nvim",
  dependencies = { "MunifTanjim/nui.nvim" },
  cmd = "CodeDiff",
  config = function()
    require("codediff").setup({
      diff = {
        disable_inlay_hints = true,
        max_computation_time_ms = 5000,
        ignore_trim_whitespace = true,
      },
      explorer = {
        position = "left",
        width = 40,
      },
      keymaps = {
        view = {
          quit = "q",
          toggle_explorer = "<leader>b",
          next_hunk = "]c",
          prev_hunk = "[c",
          next_file = "]f",
          prev_file = "[f",
          diff_get = "do",
          diff_put = "dp",
        },
        conflict = {
          -- Mapped to match your <leader>gc prefix preference
          accept_current = "<leader>gco",  -- ours
          accept_incoming = "<leader>gct", -- theirs
          accept_both = "<leader>gcb",     -- both
          discard = "<leader>gcn",         -- none
          next_conflict = "]x",
          prev_conflict = "[x",
          diffget_incoming = "2do",
          diffget_current = "3do",
        },
      },
    })

    -- CodeDiffFiller uses `default = true`, so defining it here (after setup)
    -- prevents the plugin from resetting it on subsequent opens.
    -- The plugin hardcodes fg = "#444444" which looks harsh on catppuccin-latte.
    local function set_filler_hl()
      local fg = vim.o.background == "light" and "#dde0e8" or "#444444"
      vim.api.nvim_set_hl(0, "CodeDiffFiller", { fg = fg })
    end

    set_filler_hl()
    vim.api.nvim_create_autocmd("ColorScheme", { callback = set_filler_hl })
  end,
}
