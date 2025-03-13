return {
  "sindrets/diffview.nvim",
  opts = {
    view = {
      -- Use 4-way diff (ours, base, theirs; local) for fixing conflicts
      merge_tool = {
        layout = "diff4_mixed",
        disable_diagnostics = true,
      },
    },
    default_args = {
      DiffviewOpen = { "--untracked-files=no" },
    },
  },
}
