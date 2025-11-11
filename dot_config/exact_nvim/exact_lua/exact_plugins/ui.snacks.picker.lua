return {
  "folke/snacks.nvim",
  opts = {
    picker = {
      sources = {
        explorer = {
          include = { ".env*", ".gitignore" },
        },
      },
    },
  },
  keys = {
    { "<leader>gc", false },
  },
}
