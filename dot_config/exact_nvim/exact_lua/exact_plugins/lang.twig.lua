---@type LazyPluginSpec[]
return {
  -- Treesitter configuration for Twig
  {
    "nvim-treesitter/nvim-treesitter",
    opts = {
      ensure_installed = { "html", "twig" },
    },
  },

  -- LSP configuration for Twig
  {
    "neovim/nvim-lspconfig",
    dependencies = {
      {
        "mason-org/mason.nvim",
        opts = {
          ensure_installed = {
            "twiggy-language-server",
          },
        },
      },
    },
    opts = {
      servers = {
        twiggy_language_server = {},
      },
    },
  },
}
