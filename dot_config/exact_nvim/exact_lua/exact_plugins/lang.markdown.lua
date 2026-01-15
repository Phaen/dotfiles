---@type LazyPluginSpec
return {
  "mfussenegger/nvim-lint",
  opts = {
    linters = {
      ["markdownlint-cli2"] = {
        args = { "--config", vim.fn.stdpath("config") .. "/linters/markdownlint-cli2.jsonc" },
      },
    },
  },
}
