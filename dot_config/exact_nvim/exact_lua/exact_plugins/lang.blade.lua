---@type LazyPluginSpec
return {
  -- Formatter config for blade
  {
    "conform.nvim",
    dependencies = {
      {
        "mason-org/mason.nvim",
        opts = {
          ensure_installed = {
            "blade-formatter",
          },
        },
      },
    },
    opts = {
      formatters_by_ft = {
        blade = { "blade-formatter" },
      },
    },
  },

  -- Treesitter configuration for Blade
  {
    "nvim-treesitter/nvim-treesitter",
    opts = {
      ensure_installed = { "html", "php_only", "php", "bash", "blade" },
    },
  },
}
