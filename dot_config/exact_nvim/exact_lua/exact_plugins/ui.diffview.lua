return {
  "sindrets/diffview.nvim",
  opts = function(_, opts)
    local actions = require("diffview.config").actions
    local options = { o = "ours", t = "theirs", b = "base", a = "all", n = "none" }

    local conflict_keymaps = {}
    for key, option in pairs(options) do
      -- Disable <leader>c mappings
      table.insert(conflict_keymaps, { "n", "<leader>c" .. key, false })
      table.insert(conflict_keymaps, { "n", "<leader>c" .. string.upper(key), false })

      -- Add <leader>gc mappings for single
      table.insert(
        conflict_keymaps,
        {
          "n",
          "<leader>gc" .. key,
          actions.conflict_choose(option),
          { desc = string.format("Choose '%s' version for conflict", option) },
        }
      )

      -- Add <leader>gc mappings for all
      table.insert(
        conflict_keymaps,
        {
          "n",
          "<leader>gc" .. string.upper(key),
          actions.conflict_choose_all(option),
          { desc = string.format("Choose '%s' for all conflicts", option) },
        }
      )
    end

    return vim.tbl_deep_extend("force", opts, {
      keymaps = {
        view = conflict_keymaps,
        file_panel = conflict_keymaps,
        file_history_panel = conflict_keymaps,
      },
      view = {
        merge_tool = {
          layout = "diff4_mixed",
          disable_diagnostics = true,
        },
      },
      default_args = {
        DiffviewOpen = { "--untracked-files=no" },
      },
    })
  end,
}
