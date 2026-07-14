-- Navigable git overview for the dashboard: a branch/ahead-behind line followed
-- by one selectable item per changed file (same shape as the recent files
-- section, so <CR> opens the file). The two-char status shows as a colored
-- label. Returns the child items, or nil when the cwd is not a git repo.
local function git_items()
  local root = Snacks.git.get_root()
  if root == nil then
    return nil
  end

  local function git(args)
    return vim.fn.systemlist("git " .. args)
  end

  local branch = git("branch --show-current")[1]
  if not branch or branch == "" then
    return nil
  end

  local ahead, behind = 0, 0
  local ab = git("rev-list --left-right --count @{upstream}...HEAD 2>/dev/null")[1]
  if ab then
    local b, a = ab:match("(%d+)%s+(%d+)")
    behind, ahead = tonumber(b) or 0, tonumber(a) or 0
  end

  local items = {
    {
      text = {
        { branch, hl = "Function" },
        { ("  ↑%d ↓%d"):format(ahead, behind), hl = "Comment" },
      },
      padding = 1,
    },
  }

  local status = git("status --porcelain")
  if #status == 0 then
    items[#items + 1] = { text = { { "working tree clean", hl = "Comment" } } }
    return items
  end

  for i, line in ipairs(status) do
    if i > 20 then
      items[#items + 1] = { text = { { ("… %d more"):format(#status - 20), hl = "Comment" } } }
      break
    end
    local xy, rel = line:sub(1, 2), line:sub(4)
    rel = rel:match("%->%s*(.+)$") or rel -- renames: keep the destination path
    rel = rel:gsub('^"(.*)"$', "%1") -- unquote paths with special characters
    -- worktree '?' = untracked, a 'D' in either column = delete, a non-blank
    -- index column = staged, otherwise an unstaged modification.
    local hl = xy:sub(2, 2) == "?" and "Comment"
      or (xy:find("D") and "DiagnosticError")
      or (xy:sub(1, 1) ~= " " and "DiagnosticOk")
      or "DiagnosticWarn"
    local path = root .. "/" .. rel
    items[#items + 1] = {
      file = path,
      icon = "file",
      action = ":e " .. vim.fn.fnameescape(path),
      label = { xy, hl = hl },
    }
  end

  return items
end

---@type LazyPluginSpec
return {
  "folke/snacks.nvim",
  ---@type snacks.Config
  opts = {
    dashboard = {
      width = 100,
      formats = {
        -- Show paths relative to the cwd (project root) instead of home, so the
        -- recent-files and git lists aren't dominated by a long leading path.
        file = function(item, ctx)
          local fname = vim.fn.fnamemodify(item.file, ":.")
          if fname:sub(1, 1) == "/" then -- outside the cwd: fall back to ~-relative
            fname = vim.fn.fnamemodify(item.file, ":~")
          end
          if ctx.width and #fname > ctx.width then
            fname = vim.fn.pathshorten(fname)
          end
          local dir, file = fname:match("^(.*)/(.+)$")
          return dir and { { dir .. "/", hl = "dir" }, { file, hl = "file" } } or { { fname, hl = "file" } }
        end,
      },
      preset = {
        header = [[
                                                                   
      ████ ██████           █████      ██                    
     ███████████             █████                            
     █████████ ███████████████████ ███   ███████████  
    █████████  ███    █████████████ █████ ██████████████  
   █████████ ██████████ █████████ █████ █████ ████ █████  
 ███████████ ███    ███ █████████ █████ █████ ████ █████ 
██████  █████████████████████ ████ █████ █████ ████ ██████]],
      },
      sections = {

        { section = "header", padding = 2 },
        { section = "startup", padding = 2 },
        { icon = " ", title = "Recent Files", section = "recent_files", cwd = true, indent = 2, padding = 2 },
        { icon = " ", title = "Projects", section = "projects", indent = 2, padding = 2 },
        function()
          local items = git_items()
          if not items then
            return nil
          end
          return {
          icon = " ",
          title = "Git",
          padding = 2,
          indent = 3,
          unpack(items),
          }
        end,
      },
    },
  },
}
