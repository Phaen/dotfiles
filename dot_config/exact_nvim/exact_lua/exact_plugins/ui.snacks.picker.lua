return {
  "folke/snacks.nvim",
  opts = {
    picker = {
      sources = {
        explorer = {
          include = { ".env*" },
        },
      },
    },
  },
  keys = {
    { "<leader>gc", false },
  },
}
