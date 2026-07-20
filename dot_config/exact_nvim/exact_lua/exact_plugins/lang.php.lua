-- Scan phpstan*.neon* files and return the one whose paths: match the buffer
local function find_phpstan_config(bufname)
  if bufname == "" then return nil end
  local rel_path = vim.fn.fnamemodify(bufname, ":.")
  if rel_path:sub(1, 1) == "/" then return nil end -- not under cwd

  local cwd = vim.fn.getcwd()
  local configs = vim.fn.glob(cwd .. "/phpstan*.neon*", false, true)
  for _, config_path in ipairs(configs) do
    local f = io.open(config_path, "r")
    if f then
      local in_paths = false
      for line in f:lines() do
        if line:match("^%s*paths:%s*$") then
          in_paths = true
        elseif in_paths then
          local path = line:match("^%s*-%s*(.-)%s*$")
          if path then
            local normalized = path:gsub("/+$", "") .. "/"
            if rel_path:sub(1, #normalized) == normalized then
              f:close()
              return config_path
            end
          elseif line:match("%S") then
            in_paths = false
          end
        end
      end
      f:close()
    end
  end

  return nil -- let phpstan auto-discover
end

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

-- Intelephense flags imports as unused (P1003) even when referenced in docblocks.
-- Drop those diagnostics when the symbol's short name occurs anywhere beyond the
-- use statement itself — a genuine code usage would have suppressed the warning
-- server-side, so a second occurrence can only be a docblock (or string) reference.
local function filter_docblock_unused(err, result, ctx, ...)
  if result and result.diagnostics then
    local bufnr = vim.uri_to_bufnr(result.uri)
    if vim.api.nvim_buf_is_loaded(bufnr) then
      local text = table.concat(vim.api.nvim_buf_get_lines(bufnr, 0, -1, false), "\n")
      result.diagnostics = vim.tbl_filter(function(d)
        if d.code ~= "P1003" then return true end
        local symbol = d.message:match("^Symbol '([^']+)'")
        local short = symbol and symbol:match("([^\\]+)$")
        if not short then return true end
        local occurrences = 0
        for _ in text:gmatch("%f[%w_]" .. vim.pesc(short) .. "%f[^%w_]") do
          occurrences = occurrences + 1
          if occurrences > 1 then return false end
        end
        return true
      end, result.diagnostics)
    end
  end
  return vim.lsp.handlers["textDocument/publishDiagnostics"](err, result, ctx, ...)
end

---@type LazyPluginSpec[]
return {
  -- Add treesitter syntax
  {
    "nvim-treesitter/nvim-treesitter",
    opts = { ensure_installed = { "php" } },
  },

  -- Add Mason packages
  {
    "mason-org/mason.nvim",
    opts = {
      ensure_installed = {
        -- no pint, phpcs, phpcbf: so we only use it if its installed in the project
        "php-cs-fixer", -- our backup formatter, if nothing is installed
        "phpstan",
        "phpantom_lsp",
        "php-debug-adapter",
      },
    },
  },
  {
    "neovim/nvim-lspconfig",
    opts = {
      servers = {
        -- Trialing phpantom; intelephense config kept for easy rollback.
        -- Delete the loser after the trial.
        phpantom_lsp = {},
        intelephense = {
          enabled = false,
          handlers = {
            ["textDocument/publishDiagnostics"] = filter_docblock_unused,
          },
          settings = {
            intelephense = {
              diagnostics = {
                -- Only syntax errors; everything else is phpstan's job via nvim-lint
                unexpectedTokens = true,
                undefinedTypes = false,
                undefinedFunctions = false,
                undefinedConstants = false,
                undefinedClassConstants = false,
                undefinedMethods = false,
                undefinedProperties = false,
                undefinedVariables = false,
                duplicateSymbols = false,
                unusedSymbols = true, -- phpstan has no unused-import rule
                argumentCount = false,
                deprecated = false,
              },
              environment = {
                includePaths = {
                  -- Allow stubs to be autodiscovered
                  "~/.composer/vendor/php-stubs",
                  "vendor/php-stubs",
                  "_ide_helper.php",
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
    event = { "BufReadPre", "BufNewFile" },
    opts = function(_, opts)
      local linters = { "phpstan", "phpcs" }

      opts.linters_by_ft = opts.linters_by_ft or {}
      opts.linters_by_ft.php = {}
      for _, linter in ipairs(linters) do
        if vim.fn.executable(require("lint").linters[linter].cmd()) == 1 then
          table.insert(opts.linters_by_ft.php, linter)
        end
      end

      local phpcs = require("lint").linters.phpcs
      local original_parser = phpcs.parser
      phpcs.parser = function(output, bufnr)
        local json_start = output:find("{")
        if not json_start then
          return {}
        end
        return original_parser(output:sub(json_start), bufnr)
      end

      vim.api.nvim_create_autocmd({ "BufEnter", "BufWinEnter", "BufReadPost" }, {
        pattern = "*.php",
        callback = function(ev)
          local args = { "analyze", "--error-format=json", "--no-progress", "--memory-limit=1G" }
          local config = find_phpstan_config(vim.api.nvim_buf_get_name(ev.buf))
          if config then
            vim.list_extend(args, { "-c", config })
          end
          require("lint").linters.phpstan.args = args
        end,
      })

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
