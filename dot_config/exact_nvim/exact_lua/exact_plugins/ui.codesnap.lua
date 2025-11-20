return {
  "mistricky/codesnap.nvim",
  build = "make build_generator",
  -- Only run if cargo exists
  cond = function()
    return vim.fn.executable("cargo") == 1
  end,
  opts = {
    has_breadcrumbs = true,
    has_line_number = true,
    bg_padding = 0,
    mac_window_bar = false,
  },
  keys = {
    { "<leader>cp", "<cmd>CodeSnap<cr>", mode = "x", desc = "Snap selected code to clipboard" },
    { "<leader>cP", "<cmd>CodeSnapHighlight<cr>", mode = "x", desc = "Snap selected code to clipboard with highlight" },
  },
}
