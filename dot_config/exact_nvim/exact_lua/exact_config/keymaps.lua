-- Keymaps are automatically loaded on the VeryLazy event
-- Default keymaps that are always set: https://github.com/LazyVim/LazyVim/blob/main/lua/lazyvim/config/keymaps.lua
-- Add any additional keymaps here
--
local map = vim.keymap.set
local unmap = vim.keymap.del

map("n", "<C-q>", "<cmd>q<cr>", { desc = "Quit", remap = true })

-- Deleting the last buffer leaves an empty [No Name] buffer; land on the
-- dashboard instead. Delete first, then reopen once the window has settled on
-- its replacement buffer (scheduling avoids racing Snacks.bufdelete).
local function delete_buffer_to_dashboard()
  Snacks.bufdelete()
  vim.schedule(function()
    local buf = vim.api.nvim_get_current_buf()
    local win = vim.api.nvim_get_current_win()
    if vim.api.nvim_buf_get_name(buf) == "" and vim.bo[buf].filetype == "" and not vim.bo[buf].modified then
      require("snacks.dashboard").open({ buf = buf, win = win })
    end
  end)
end

map("n", "<leader>bd", delete_buffer_to_dashboard, { desc = "Delete Buffer (or Dashboard)" })

-- Resize the current window to fit its widest line, then hand the freed (or
-- borrowed) columns to the windows sharing its horizontal band, split by their
-- current width ratios.
-- Widest line, but a handful of freak-long lines (e.g. one enormous migration
-- name among short filenames) are dropped so they don't blow up the whole
-- window. Freaks are found by a gap: with widths sorted ascending, scan the top
-- slice (never more than ~10% of lines) from the largest down, and cut at the
-- first jump where a line is >=1.3x the one just below it. Everything above the
-- cut is a freak; the width just below it is used. No qualifying gap in the top
-- slice means the distribution is smooth, so every line is honoured.
local FREAK_FACTOR = 1.3
local FREAK_SHARE = 0.10

local function content_width(buf)
  local widths, max_w = {}, 0
  for _, line in ipairs(vim.api.nvim_buf_get_lines(buf, 0, -1, false)) do
    local w = vim.fn.strdisplaywidth(line)
    widths[#widths + 1] = w
    if w > max_w then
      max_w = w
    end
  end

  local n = #widths
  if n < 5 then
    return max_w
  end

  table.sort(widths)
  local lo = math.max(2, n - math.max(1, math.floor(n * FREAK_SHARE)) + 1)
  for i = n, lo, -1 do
    if widths[i] >= widths[i - 1] * FREAK_FACTOR then
      return widths[i - 1]
    end
  end
  return max_w
end

local function fit_window_width()
  local cur = vim.api.nvim_get_current_win()
  local buf = vim.api.nvim_win_get_buf(cur)

  local content = content_width(buf)

  local info = vim.fn.getwininfo(cur)[1]
  local desired = content + info.textoff + 1
  desired = math.max(desired, 1)
  desired = math.min(desired, math.floor(vim.o.columns * 0.7))

  -- Peers = other windows whose vertical extent overlaps the current one, i.e.
  -- those actually competing for horizontal space in this row.
  local top, bot = info.winrow, info.winrow + info.height
  local peers, peer_total = {}, 0
  for _, w in ipairs(vim.fn.getwininfo()) do
    if w.tabnr == info.tabnr and w.winid ~= cur then
      if w.winrow < bot and (w.winrow + w.height) > top then
        peers[#peers + 1] = w
        peer_total = peer_total + w.width
      end
    end
  end

  local old = vim.api.nvim_win_get_width(cur)
  vim.api.nvim_win_set_width(cur, desired)

  if peer_total == 0 then
    return
  end

  -- Redistribute the delta so the remaining space keeps each peer's old ratio.
  local budget = peer_total + old - desired
  local assigned, last = 0, nil
  for _, w in ipairs(peers) do
    last = w.winid
    local target = math.max(1, math.floor(budget * w.width / peer_total + 0.5))
    assigned = assigned + target
    vim.api.nvim_win_set_width(w.winid, target)
  end
  -- Absorb rounding drift into the last peer so totals stay exact.
  if last then
    vim.api.nvim_win_set_width(last, vim.api.nvim_win_get_width(last) + (budget - assigned))
  end
end

vim.api.nvim_create_user_command("FitWidth", fit_window_width, { desc = "Fit window width to content" })
map("n", "<C-w>C", fit_window_width, { desc = "Fit Window Width to Content" })
