-- Derive "namespace/project" from the git remote (GitLab subgroups collapse
-- to the last two path components). Empty string if not in a repo.
local function git_project()
  local remote = vim.fn.systemlist("git remote get-url origin")[1]
  if vim.v.shell_error ~= 0 or not remote or remote == "" then
    return ""
  end
  remote = remote:gsub("%.git%s*$", "")
  return remote:match("[:/]([^:/]+/[^/]+)$") or ""
end

return {
  "mistricky/codesnap.nvim",
  build = "make build_generator",
  -- Only run if cargo exists
  cond = function()
    return vim.fn.executable("cargo") == 1
  end,
  opts = function()
    return {
      show_line_number = true,
      show_workspace = false,
      snapshot_config = {
        theme = "candy",
        -- Repurposed: show the repo's namespace/project instead of branding.
        watermark = {
          content = git_project(),
        },
        window = {
          mac_window_bar = true,
        },
        code_config = {
          breadcrumbs = {
            enable = true,
          },
        },
      },
    }
  end,
  keys = {
    { "<leader>cp", "<cmd>CodeSnap<cr>", mode = "x", desc = "Snap selected code to clipboard" },
    { "<leader>cP", "<cmd>CodeSnapHighlight<cr>", mode = "x", desc = "Snap selected code to clipboard with highlight" },
  },
}
