return {
  "sindrets/diffview.nvim",
  opts = function(_, opts)
    local actions = require("diffview.config").actions
    local conflict_keymaps = {
      { "n", "<leader>co", false },
      { "n", "<leader>ct", false },
      { "n", "<leader>cb", false },
      { "n", "<leader>ca", false },
      { "n", "<leader>cn", false },
      { "n", "<leader>cO", false },
      { "n", "<leader>cT", false },
      { "n", "<leader>cB", false },
      { "n", "<leader>cA", false },
      { "n", "<leader>cN", false },
      { "n", "<leader>gco", actions.conflict_choose("ours"), { desc = "Choose 'ours' version for conflict" } },
      { "n", "<leader>gct", actions.conflict_choose("theirs"), { desc = "Choose 'theirs' version for conflict" } },
      { "n", "<leader>gcb", actions.conflict_choose("base"), { desc = "Choose 'base' version for conflict" } },
      { "n", "<leader>gca", actions.conflict_choose("all"), { desc = "Choose 'all' versions for conflict" } },
      { "n", "<leader>gcn", actions.conflict_choose("none"), { desc = "Choose 'none' version for conflict" } },
      { "n", "<leader>gcO", actions.conflict_choose_all("ours"), { desc = "Choose 'ours' for all conflicts" } },
      { "n", "<leader>gcT", actions.conflict_choose_all("theirs"), { desc = "Choose 'theirs' for all conflicts" } },
      { "n", "<leader>gcB", actions.conflict_choose_all("base"), { desc = "Choose 'base' for all conflicts" } },
      { "n", "<leader>gcA", actions.conflict_choose_all("all"), { desc = "Choose 'all' for all conflicts" } },
      { "n", "<leader>gcN", actions.conflict_choose_all("none"), { desc = "Choose 'none' for all conflicts" } },
    }

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
