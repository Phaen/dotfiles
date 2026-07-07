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
      },
      view = {
        -- Side-by-side for normal diffs.
        default = { layout = "diff2_horizontal" },
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

    -- The piece that didn't exist when diffview was first abandoned: native
    -- char-level inline highlighting. diffview runs on real diff-mode windows,
    -- so this global applies inside it. (linematch is already set elsewhere in
    -- your config, which aligns hunks so the char diff lands on the right lines.)
    vim.opt.diffopt:append("inline:char")

    -- Mirror codediff's runtime colors so both tools look identical, and pin
    -- diffview's *own* groups (not just base Diff*) since enhanced_diff_hl makes
    -- diffview render through them. Setting them here also overrides the Comment
    -- relink that made deletions too dark on latte.
    --   filler      -> CodeDiffFiller     (tuned in ui.codediff; fg=bg hides the
    --                                       fillchar slashes into a solid wash)
    --   add         -> CodeDiffLineInsert  (added lines, right/new side)
    --   del         -> CodeDiffLineDelete  (removed lines, left/old side)
    --   text        -> CodeDiffCharDelete  (changed chars, two-tier pop)
    local function set_diff_hl()
      local c = vim.o.background == "light"
          and { filler = "#dde0e8", add = "#d0e2d1", del = "#eac8d3", text = "#d7b8c2" }
          or { filler = "#444444", add = "#364143", del = "#443244", text = "#5f465f" }
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
      -- Changed lines + the changed chars within them (two-tier pop).
      hl("DiffChange", { bg = c.del })
      hl("DiffviewDiffChange", { bg = c.del })
      hl("DiffText", { bg = c.text })
      hl("DiffviewDiffText", { bg = c.text })
    end

    set_diff_hl()
    -- Runs after diffview's own ColorScheme handler (registered during setup
    -- above), so our overrides win over its re-derived defaults.
    vim.api.nvim_create_autocmd("ColorScheme", { callback = set_diff_hl })
  end,
}
