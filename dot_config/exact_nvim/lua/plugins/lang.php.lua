-- Get target directory from docker compose container that cwd is bound to
local function get_docker_target()
  local handle = io.popen("docker compose ps --format '{{.Labels}}'")
  if handle then
    local result = handle:read("*a")
    handle:close()

    local cwd = vim.fn.getcwd()

    for labels in result:gmatch("[^\r\n]+") do
      for label, value in string.gmatch(labels, "([^,]+)=([^,]+)") do
        if string.match(label, "Source$") and value == cwd then
          local target_label = string.gsub(label, "Source$", "Target")
          for l, v in string.gmatch(labels, "([^,]+)=([^,]+)") do
            if l == target_label then
              return v
            end
          end
        end
      end
    end
  end
  return "/var/www/html" -- hail mary
end

---@type LazyPluginSpec
return {
  -- Add treesitter syntax
  {
    "nvim-treesitter/nvim-treesitter",
    opts = { ensure_installed = { "php" } },
  },

  -- Add Mason packages
  {
    "williamboman/mason.nvim",
    opts = {
      ensure_installed = {
        -- no pint, phpcs, phpcbf: so we only use it if its installed in the project
        "php-cs-fixer", -- our backup formatter, if nothing is installed
        "phpstan",
        "intelephense",
        "php-debug-adapter",
      },
    },
  },
  {
    "neovim/nvim-lspconfig",
    opts = {
      servers = {
        intelephense = {
          settings = {
            intelephense = {
              environment = {
                includePaths = {
                  -- Allow stubs to be autodiscovered
                  "~/.composer/vendor/php-stubs",
                  "vendor/php-stubs",
                },
              },
              files = {
                -- Default of 1 MB is way too low for autoload and class files
                maxSize = 100000000,
              },
            },
          },
        },
      },
    },
  },
  -- Configure debugger with xdebug
  {
    "mfussenegger/nvim-dap",
    opts = function()
      local dap = require("dap")

      -- Configure adapter
      local path = require("mason-registry").get_package("php-debug-adapter"):get_install_path()
      dap.adapters.php = {
        type = "executable",
        command = "node",
        args = { path .. "/extension/out/phpDebug.js" },
      }

      -- Configure adapter configurations
      local base_config = {
        type = "php",
        request = "launch",
        port = 9003,
        xdebugSettings = {
          max_children = 100,
        },
      }

      dap.configurations.php = {
        vim.tbl_extend("force", base_config, {
          name = "PHP: Xdebug docker",
          pathMappings = function()
            return {
              [get_docker_target()] = "${workspaceFolder}",
            }
          end,
        }),
        vim.tbl_extend("force", base_config, {
          name = "PHP: Xdebug local",
        }),
      }
    end,
  },
  -- Configure formatters, only runs the first that is installed in the project
  {
    "stevearc/conform.nvim",
    opts = {
      formatters_by_ft = {
        php = { "pint", "phpcbf", "php_cs_fixer", stop_after_first = true },
      },
    },
  },
  -- Configure linters, conditionally add them depending on which are installed in the project
  {
    "mfussenegger/nvim-lint",
    opts = function(_, opts)
      local linters = { "phpstan", "phpcs" }

      opts.linters_by_ft = opts.linters_by_ft or {}
      opts.linters_by_ft.php = {}
      for _, linter in ipairs(linters) do
        if vim.fn.executable(require("lint").linters[linter].cmd()) == 1 then
          table.insert(opts.linters_by_ft.php, linter)
        end
      end

      return opts
    end,
  },
  -- Configure tests with pest
  {
    "nvim-neotest/neotest",
    dependencies = {
      "V13Axel/neotest-pest",
    },
    config = function()
      require("neotest").setup({
        adapters = {
          require("neotest-pest"),
        },
      })
    end,
  },
}
