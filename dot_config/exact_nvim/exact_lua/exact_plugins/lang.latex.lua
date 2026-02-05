-- LaTeX configuration with vimtex and tectonic

---@type LazyPluginSpec[]
return {
  -- Vimtex plugin
  {
    "lervag/vimtex",
    lazy = false, -- Required for inverse search to work
    init = function()
      -- Use tectonic as the compiler
      vim.g.vimtex_compiler_method = "tectonic"
      -- Disable default keymaps (they're broken)
      vim.g.vimtex_mappings_enabled = 0

      -- Suppress compile output messages
      vim.g.vimtex_compiler_silent = 1

      -- Platform-specific PDF viewer and compiler options
      if vim.fn.has("mac") == 1 then
        -- macOS: Use Skim with synctex support
        vim.g.vimtex_view_method = "skim"
        vim.g.vimtex_view_skim_sync = 1 -- Forward sync after compile
        vim.g.vimtex_view_skim_activate = 0 -- Don't steal focus
        vim.g.vimtex_compiler_tectonic = {
          options = { "--synctex" },
        }
      else
        -- Other platforms: use system default viewer, no synctex
        vim.g.vimtex_view_method = "general"
        vim.g.vimtex_view_general_viewer = vim.fn.has("win32") == 1 and "start" or "xdg-open"
        vim.g.vimtex_compiler_tectonic = { options = {} }
      end

      -- Compile on save (enabled by default)
      vim.g.vimtex_compile_on_save = true

      -- Compile on save autocmd
      vim.api.nvim_create_autocmd("BufWritePost", {
        pattern = "*.tex",
        callback = function()
          if vim.g.vimtex_compile_on_save then
            vim.cmd("VimtexCompile")
          end
        end,
      })
    end,
    keys = {
      { "<localleader>ll", "<cmd>VimtexCompile<cr>", desc = "Compile", ft = "tex" },
      { "<localleader>lv", "<cmd>VimtexView<cr>", desc = "View PDF", ft = "tex" },
      { "<localleader>lt", "<cmd>VimtexTocToggle<cr>", desc = "Toggle TOC", ft = "tex" },
      { "<localleader>lc", "<cmd>VimtexClean<cr>", desc = "Clean aux files", ft = "tex" },
      { "<localleader>le", "<cmd>VimtexErrors<cr>", desc = "Show errors", ft = "tex" },
      { "<localleader>lk", "<cmd>VimtexStop<cr>", desc = "Stop compilation", ft = "tex" },
      { "<localleader>li", "<cmd>VimtexInfo<cr>", desc = "Vimtex info", ft = "tex" },
      { "<localleader>ll", "<plug>(vimtex-compile-selected)", desc = "Compile selection", ft = "tex", mode = "x", silent = true },
      {
        "<localleader>la",
        function()
          vim.g.vimtex_compile_on_save = not vim.g.vimtex_compile_on_save
          vim.notify("Compile on save: " .. (vim.g.vimtex_compile_on_save and "enabled" or "disabled"))
        end,
        desc = "Toggle compile on save",
        ft = "tex",
      },
    },
  },

  -- which-key group name
  {
    "folke/which-key.nvim",
    opts = {
      spec = {
        { "<localleader>l", group = "latex", mode = { "n", "x" } },
      },
    },
  },

  -- Disable treesitter syntax highlighting for latex
  {
    "nvim-treesitter/nvim-treesitter",
    opts = function(_, opts)
      opts.highlight = opts.highlight or {}
      opts.highlight.disable = opts.highlight.disable or {}
      if type(opts.highlight.disable) == "table" then
        vim.list_extend(opts.highlight.disable, { "latex" })
      end
    end,
  },
}
