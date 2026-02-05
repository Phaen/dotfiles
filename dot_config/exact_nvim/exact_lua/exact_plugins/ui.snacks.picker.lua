return {
  "folke/snacks.nvim",
  opts = {
    image = {
      enabled = true,
      doc = {
        -- Render PDFs opened in buffers
        enabled = true,
      },
    },
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
    { "<leader>fa", false },
    { "<leader>ff", false },
    { "<leader>fg", false },
    { "<leader><space>", false },
  },
}
