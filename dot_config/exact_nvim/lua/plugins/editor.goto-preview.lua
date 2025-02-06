return {
  "rmagatti/goto-preview",
  event = "BufEnter",
  opts = {
    default_mappings = false,
  },
  keys = function()
    return {
      { "gp", "", desc = "Preview", mode = "n" },
      { "gpd", require("goto-preview").goto_preview_definition, desc = "Preview definition" },
      { "gpy", require("goto-preview").goto_preview_type_definition, desc = "Preview type definition" },
      { "gpI", require("goto-preview").goto_preview_implementation, desc = "Preview implementation" },
      { "gpD", require("goto-preview").goto_preview_declaration, desc = "Preview declaration" },
      { "gP", require("goto-preview").close_all_win, desc = "Close preview windows" },
      -- Requires Telescope
      --{ "gpr",  require("goto-preview").goto_preview_references() , desc = "Preview references" },
    }
  end,
}
