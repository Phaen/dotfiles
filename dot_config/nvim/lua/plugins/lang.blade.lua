---@type LazyPluginSpec
return {
  -- Formatter config for blade
  {
    "conform.nvim",
    dependencies = {
      {
        "williamboman/mason.nvim",
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
    config = function(_, opts)
      local parser_config = require("nvim-treesitter.parsers").get_parser_configs()
      parser_config.blade = {
        install_info = {
          url = "https://github.com/EmranMR/tree-sitter-blade",
          files = { "src/parser.c" },
          branch = "main",
        },
      }

      vim.filetype.add({
        pattern = {
          [".*%.blade%.php"] = "blade",
        },
      })

      require("nvim-treesitter.configs").setup(opts)
    end,
  },
  -- Completions for Blade
  -- WARN: Currently useless in this config, because of no blink support
  {
    "ricardoramirezr/blade-nav.nvim",
    ft = { "blade", "php" },
    opts = {
      close_tag_on_complete = true,
    },
  },
}
