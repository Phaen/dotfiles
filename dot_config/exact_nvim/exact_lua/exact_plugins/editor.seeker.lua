return {
  "2kabhishek/seeker.nvim",
  dependencies = { "folke/snacks.nvim" },
  cmd = { "Seeker" },
  keys = {
    { "<leader>fa", ":Seeker files<CR>", desc = "Seek Files" },
    { "<leader>ff", ":Seeker git_files<CR>", desc = "Seek Git Files" },
    { "<leader><space>", ":Seeker files<CR>", desc = "Seek Files" },
    { "<leader>fg", ":Seeker grep<CR>", desc = "Seek Grep" },
  },
  opts = {},
}
