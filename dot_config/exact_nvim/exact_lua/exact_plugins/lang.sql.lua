---@type LazyPluginSpec
return {
  {
    "mason-org/mason.nvim",
    opts = { ensure_installed = { "sql-formatter" } },
  },
  {
    "stevearc/conform.nvim",
    opts = {
      formatters_by_ft = {
        sql = { "sql_formatter" },
      },
    },
  },
}
