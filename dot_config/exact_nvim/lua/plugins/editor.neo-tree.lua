---@type LazyPluginSpec
return {
  "nvim-neo-tree/neo-tree.nvim",
  opts = {
    filesystem = {
      filtered_items = {
        hide_by_name = {
          "node_modules",
          "vendor",
          "/build/",
          "/dist/",
          "npm-shrinkwrap.json",
        },
        hide_by_pattern = {
          ".log*",
          "*-lock.json",
          "*.lock",
          "*.meta",
          "*.cache",
          "_*",
        },
        always_show_by_pattern = {
          ".env*",
        },
        never_show = {
          ".DS_Store",
          "thumbs.db",
        },
        never_show_by_pattern = {
          ".null-ls_*",
          ".conform*",
          "*~",
        },
      },
    },
    open_files_do_not_replace_types = { "terminal", "Trouble", "trouble", "qf", "Outline", "prompt", "nofile" },
  },
}
