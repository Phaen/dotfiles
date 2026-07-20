return {
  "folke/snacks.nvim",
  init = function()
    -- The explorer follows the current file (follow_file), but when the
    -- explorer isn't focused its cursorline falls back to the dim `CursorLine`
    -- group, so the tracked file is invisible. Give picker-list windows a
    -- private highlight namespace where `CursorLine` is bright. The editor
    -- (namespace 0) is untouched, and a focused picker remaps CursorLine via
    -- winhighlight to `SnacksPickerListCursorLine` (unaffected here), so only
    -- the unfocused explorer lights up. This marks the *current* buffer.
    local ns = vim.api.nvim_create_namespace("snacks_explorer_cursorline")
    vim.api.nvim_set_hl(ns, "CursorLine", { link = "Visual" })
    vim.api.nvim_create_autocmd("FileType", {
      pattern = "snacks_picker_list",
      callback = function(ev)
        vim.schedule(function()
          for _, win in ipairs(vim.fn.win_findbuf(ev.buf)) do
            vim.api.nvim_win_set_hl_ns(win, ns)
          end
        end)
      end,
    })

    -- Filename color for files that have an open (listed) buffer. Tune freely.
    vim.api.nvim_set_hl(0, "SnacksExplorerBufOpen", { link = "Special", default = true })

    -- The formatter above only runs when the list re-renders, which buffer
    -- open/close doesn't trigger by itself — the tint otherwise piggybacks on
    -- incidental redraws (fs events, follow_file scrolling). The schedule also
    -- puts BufDelete past the actual unlisting, so the tint clears correctly.
    vim.api.nvim_create_autocmd({ "BufAdd", "BufDelete" }, {
      callback = function(ev)
        if not _G.Snacks or vim.bo[ev.buf].buftype ~= "" then
          return
        end
        vim.schedule(function()
          for _, p in ipairs(Snacks.picker.get({ source = "explorer" })) do
            p.list:update({ force = true })
          end
        end)
      end,
    })
  end,
  opts = {
    image = {
      enabled = true,
      doc = {
        -- Render PDFs opened in buffers
        enabled = true,
      },
    },
    picker = {
      sources = {
        explorer = {
          include = { ".env*", ".gitignore" },
          -- Tint file nodes that have an open (listed) buffer, then defer to the
          -- stock formatter. `bufnr` resolves the path to a buffer (an exact
          -- full-path match wins over its pattern fallback, and the name check
          -- guards the rare regex coincidence). `filename_hl` is honored by
          -- picker.format.file; clearing it to nil reverts a node once its
          -- buffer is closed.
          format = function(item, picker)
            if item.file and not item.dir then
              local b = vim.fn.bufnr(item.file)
              local open = b > 0
                and vim.bo[b].buflisted
                and vim.fs.normalize(vim.api.nvim_buf_get_name(b)) == vim.fs.normalize(item.file)
              item.filename_hl = open and "SnacksExplorerBufOpen" or nil
            end
            return Snacks.picker.format.file(item, picker)
          end,
        },
      },
    },
  },
  keys = {
    { "<leader>gc", false },
    { "<leader>fa", false },
    { "<leader>ff", false },
    { "<leader>fg", false },
    { "<leader><space>", false },
  },
}
