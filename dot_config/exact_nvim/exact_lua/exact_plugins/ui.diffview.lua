return {
  -- Maintained fork of the abandoned sindrets/diffview.nvim (original last
  -- pushed Aug 2024). This fork is ~133 commits ahead with the backlog of bug
  -- fixes applied. Repo was renamed diffview.nvim -> diffview-plus.nvim.
  "dlyongemallo/diffview-plus.nvim",
  cmd = { "DiffviewOpen", "DiffviewFileHistory" },
  keys = {
    { "<leader>gdd", "<cmd>DiffviewOpen<cr>", desc = "Diffview: working tree" },
    { "<leader>gdc", "<cmd>DiffviewOpen HEAD~1<cr>", desc = "Diffview: last commit" },
    {
      "<leader>gdm",
      function()
        -- Resolve the remote's default branch (acceptance, main, master, ...)
        -- rather than hardcoding one. origin/HEAD is a symbolic ref pointing at
        -- it; `git remote set-head origin -a` populates it if missing.
        local ref = vim.fn.systemlist("git symbolic-ref --short refs/remotes/origin/HEAD 2>/dev/null")[1]
        if not ref or ref == "" then
          vim.notify(
            "origin/HEAD not set. Run: git remote set-head origin -a",
            vim.log.levels.WARN
          )
          return
        end
        vim.cmd("DiffviewOpen " .. ref .. "...HEAD")
      end,
      desc = "Diffview: what branch introduced (vs default)",
    },
    { "<leader>gdh", "<cmd>DiffviewFileHistory %<cr>", desc = "Diffview: file history" },
    { "<leader>gdH", "<cmd>DiffviewFileHistory<cr>", desc = "Diffview: repo history" },
  },
  -- diffview registers its own SessionLoadPost handler in plugin/diffview.lua,
  -- which never runs at session-load time under cmd/keys lazy loading. Without
  -- it, the `edit diffview://...` lines :mksession wrote come back as empty,
  -- unflagged buffers, and the next DiffviewOpen on the same rev dies with
  -- "Failed to create diff buffer" on the name collision. init runs eagerly,
  -- so the hook is armed before persistence.nvim sources the session; the
  -- require inside only pulls diffview in when a session is actually restored.
  init = function()
    vim.api.nvim_create_autocmd("SessionLoadPost", {
      group = vim.api.nvim_create_augroup("diffview_session_lazy", { clear = true }),
      callback = function()
        vim.schedule(function()
          local session = require("diffview.session")
          session.cleanup()
          -- Deferred so the TabClosed/WinClosed autocmds queued by cleanup
          -- land before restore opens a view.
          vim.schedule(session.restore)
        end)
      end,
    })
  end,
  config = function()
    require("diffview").setup({
      -- ON so old-side deletions render through DiffviewDiffAddAsDelete instead
      -- of raw DiffAdd (green). Native diff mode has no old/new concept — a
      -- deleted line still exists in the left buffer, so vim flags it as "added"
      -- there. enhanced_diff_hl is what gives it delete semantics. The theme's
      -- Comment relink it also does (too dark on latte) is neutralised by
      -- overriding the Diffview* groups directly in set_diff_hl below.
      enhanced_diff_hl = true,
      -- --imply-local: when a range points at HEAD (our origin/HEAD...HEAD map),
      -- pin that end to the local working tree so the RIGHT side is editable
      -- instead of a read-only commit buffer.
      default_args = {
        DiffviewOpen = { "--imply-local" },
      },
      -- Ignore whitespace while diffview is open (scoped; restored on close).
      -- iwhiteall == git -w. Honoured for hunk computation, so whitespace-only
      -- changes drop from the hunks and the file list, not just the highlight.
      diffopt = {
        iwhiteall = true,
        algorithm = "histogram",
      },
      view = {
        -- Side-by-side for normal diffs.
        default = { layout = "diff2_horizontal" },
        -- Added/untracked/deleted files have nothing on one side, so instead
        -- of a half-empty split, render them as a single full-width window
        -- (diff1_raw). Added files stay editable when the b-side is LOCAL.
        one_sided_layout = "raw",
        -- 3-way merge: local | result | remote, with the base available.
        merge_tool = {
          layout = "diff3_horizontal",
          disable_diagnostics = true,
        },
        file_history = { layout = "diff2_horizontal" },
      },
      file_panel = {
        listing_style = "tree", -- directory tree, not a flat list
        win_config = { position = "left", width = 40 },
      },
      keymaps = {
        view = {
          { "n", "]c", require("diffview.actions").select_next_entry, { desc = "Next file" } },
          { "n", "[c", require("diffview.actions").select_prev_entry, { desc = "Prev file" } },
        },
      },
    })

    -- Char-level inline highlighting; applies inside diffview's diff-mode windows.
    vim.opt.diffopt:append("inline:char")

    local function set_diff_hl()
      local c = vim.o.background == "light"
          and { filler = "#dde0e8", add = "#d0e2d1", del = "#eac8d3", chg = "#ecd9bd", chgtext = "#e0c599" }
          or { filler = "#444444", add = "#364143", del = "#443244", chg = "#4a3f2a", chgtext = "#65552f" }
      local hl = function(g, o) vim.api.nvim_set_hl(0, g, o) end

      -- Deleted-line filler: fg=bg collapses the slashes into a solid block.
      hl("DiffDelete", { fg = c.filler, bg = c.filler })
      hl("DiffviewDiffDelete", { fg = c.filler, bg = c.filler })
      hl("DiffviewDiffDeleteDim", { fg = c.filler, bg = c.filler })
      -- Added content (new/right side).
      hl("DiffAdd", { bg = c.add })
      hl("DiffviewDiffAdd", { bg = c.add })
      -- Removed content (old/left side) — this is the group enhanced_diff_hl
      -- routes deletions to instead of green DiffAdd. bg only so the deleted
      -- code stays readable via its syntax fg.
      hl("DiffviewDiffAddAsDelete", { bg = c.del })
      hl("DiffChange", { bg = c.chg })
      hl("DiffviewDiffChange", { bg = c.chg })
      hl("DiffText", { bg = c.chgtext })
      hl("DiffviewDiffText", { bg = c.chgtext })
    end

    set_diff_hl()
    -- Runs after diffview's own ColorScheme handler (registered during setup
    -- above), so our overrides win over its re-derived defaults.
    vim.api.nvim_create_autocmd("ColorScheme", { callback = set_diff_hl })

    -- A jump out of a diff window (gd, gf, a picker, ...) swaps that window's
    -- buffer and leaves the opposite side on the previous file, so the two
    -- panes stop describing the same thing. Rebind the whole layout to the
    -- entry the jump landed in, carrying the cursor over.
    local function sync_layout_to_buf(bufnr, winid)
      local lib = require("diffview.lib")
      local DiffView = require("diffview.scene.views.diff.diff_view").DiffView
      local view = lib.get_current_view()

      if not (view and view.cur_layout and view:instanceof(DiffView)) then
        return
      end

      -- Only jumps made from inside the diff layout count; the file panel and
      -- any window outside the view are none of our business.
      local win_obj
      for _, win in ipairs(view.cur_layout.windows) do
        if win.id == winid then
          win_obj = win
          break
        end
      end
      if not win_obj then
        return
      end

      -- buftype filters out diffview://, which is how every non-local side of
      -- an entry is rendered — those are never a stray jump.
      local name = vim.api.nvim_buf_get_name(bufnr)
      if name == "" or vim.bo[bufnr].buftype ~= "" then
        return
      end

      -- Diffview swapping in a buffer it owns has already updated the window's
      -- attached file, so the two agree. A stray jump leaves them disagreeing.
      if win_obj.file and win_obj.file.bufnr == bufnr then
        return
      end

      local target = vim.fs.normalize(name)
      local entry
      for _, file in view.files:iter() do
        if vim.fs.normalize(file.absolute_path) == target then
          entry = file
          break
        end
      end

      -- Until the layout is rebound, the panes hold unrelated files and vim
      -- would redraw a whole-file diff between them. Drop diff mode now, while
      -- still inside the autocmd, so that frame never renders. Reopening the
      -- entry restores it: every File carries `diff = true` in its winopts.
      local diffed = {}
      for _, win in ipairs(view.cur_layout.windows) do
        if win.id and vim.api.nvim_win_is_valid(win.id) and vim.wo[win.id].diff then
          vim.wo[win.id].diff = false
          diffed[#diffed + 1] = win.id
        end
      end

      local function restore_diff()
        for _, id in ipairs(diffed) do
          if vim.api.nvim_win_is_valid(id) then
            vim.wo[id].diff = true
          end
        end
      end

      -- Deferred: diffview's own entry switches fire BufWinEnter too, before
      -- cur_entry catches up. Re-reading cur_entry a tick later makes those a
      -- no-op and doubles as the re-entrancy guard for our own set_file.
      vim.schedule(function()
        if not lib.has_view(view) then
          return
        end

        if view.cur_entry == entry then
          restore_diff()
          return
        end

        if not entry then
          vim.notify(
            vim.fn.fnamemodify(name, ":.") .. " is not part of this diff",
            vim.log.levels.WARN
          )
          return
        end

        -- cursor_map is consumed by the file_open_new listener, which lands
        -- the main window here instead of on the first hunk.
        if vim.api.nvim_win_is_valid(winid) then
          view.cursor_map[entry.path] = vim.api.nvim_win_call(winid, vim.fn.winsaveview)
        end

        view:set_file(entry, true)
      end)
    end

    vim.api.nvim_create_autocmd("BufWinEnter", {
      group = vim.api.nvim_create_augroup("diffview_follow_jump", { clear = true }),
      callback = function(args)
        sync_layout_to_buf(args.buf, vim.api.nvim_get_current_win())
      end,
    })
  end,
}
