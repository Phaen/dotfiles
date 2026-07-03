return {
  "dnlhc/glance.nvim",
  cmd = "Glance",
  opts = {},
  keys = {
    { "gp", "", desc = "Preview", mode = "n" },
    { "gpd", "<cmd>Glance definitions<cr>", desc = "Preview definition" },
    { "gpy", "<cmd>Glance type_definitions<cr>", desc = "Preview type definition" },
    { "gpI", "<cmd>Glance implementations<cr>", desc = "Preview implementation" },
    { "gpr", "<cmd>Glance references<cr>", desc = "Preview references" },
    { "gP", "<cmd>Glance resume<cr>", desc = "Resume last preview" },
  },
}
