return {
  "rmagatti/goto-preview",
  dependencies = { "rmagatti/logger.nvim" },
  event = "BufEnter",
  opts = {
    default_mappings = false,
  },
  keys = {
    { "gp", "", desc = "Preview", mode = "n" },
    {
      "gpd",
      function()
        require("goto-preview").goto_preview_definition()
      end,
      desc = "Preview definition",
    },
    {
      "gpy",
      function()
        require("goto-preview").goto_preview_type_definition()
      end,
      desc = "Preview type definition",
    },
    {
      "gpI",
      function()
        require("goto-preview").goto_preview_implementation()
      end,
      desc = "Preview implementation",
    },
    {
      "gpD",
      function()
        require("goto-preview").goto_preview_declaration()
      end,
      desc = "Preview declaration",
    },
    {
      "gpr",
      function()
        require("goto-preview").goto_preview_references()
      end,
      desc = "Preview references",
    },
    {
      "gP",
      function()
        require("goto-preview").close_all_win()
      end,
      desc = "Close preview windows",
    },
  },
}
