-- difffold: structural folds for diff windows.
--
-- foldmethod=diff folds every unchanged run minus `context:N` lines, so fold
-- edges land mid-function and the code around a hunk loses its frame. This
-- replaces those folds with manual ones along the treesitter syntax tree:
-- the outermost multi-line node that holds no change is folded whole, and a
-- node holding a change is descended into. So an untouched method inside a
-- touched class folds, as does an untouched call, array or closure inside a
-- touched function. Statements inside a touched function stay open, so its
-- control flow remains visible around the hunks.
--
-- Language-agnostic: any parser works, no folds query needed. When neither
-- side has a parser, the stock diff folds stay.
--
-- Wired up in the diff_buf_win_enter hook of lua/plugins/ui.diffview.lua, for
-- two-way diffs only; three-way merges keep the stock folds. The folds are
-- manual and computed once on entering the file, so they go stale while
-- editing; `:lua require("difffold").apply_pair(<win>, <other win>)`
-- recomputes them.
--
-- Both panes must carry identical folds: a fold on one side without its
-- counterpart on the other shifts every line below it out of alignment.
-- Hence apply_pair reads the tree of one side only and mirrors the result.

local M = {}

M.config = {
  -- Nodes shorter than this stay open; folding them saves nothing.
  min_lines = 3,
  -- Below a touched node whose type matches function_pattern, nodes whose
  -- type matches open_pattern are never folded, only descended into. Both are
  -- `|`-separated plain substrings of treesitter node types, not Lua patterns.
  function_pattern = "function|method|lambda|closure|arrow|constructor",
  open_pattern = "statement|clause|block|body|case|default",
}

-- Called with the window current; diff_hlID/diff_filler only see that window.
local function range_changed(s, e)
  for l = s, e do
    if vim.fn.diff_hlID(l, 1) ~= 0 then
      return true
    end
    -- Filler above line s sits before the unit, not inside it.
    if l > s and vim.fn.diff_filler(l) > 0 then
      return true
    end
  end
  return false
end

local function matches(type, pattern)
  for alt in pattern:gmatch("[^|]+") do
    if type:find(alt, 1, true) then
      return true
    end
  end
  return false
end

-- Folds for the unchanged syntactic units of the buffer in `winid`, or nil
-- when the buffer has no parser.
local function compute(winid)
  local bufnr = vim.api.nvim_win_get_buf(winid)
  local parser = vim.treesitter.get_parser(bufnr, nil, { error = false })
  if not parser then
    return nil
  end
  local root = parser:parse()[1]:root()

  local folds = {}
  vim.api.nvim_win_call(winid, function()
    local function walk(node, in_fn)
      local sr, _, er, ec = node:range()
      -- An end column of 0 means the node stops at the newline before er.
      local s, e = sr + 1, ec == 0 and er or er + 1
      if e - s + 1 < M.config.min_lines then
        return
      end
      local type = node:type()
      local last = folds[#folds]
      -- Sibling nodes can share a line (`)->bar(`); folds may not overlap.
      if
        (not in_fn or not matches(type, M.config.open_pattern))
        and not (last and s <= last[2])
        and not range_changed(s, e)
      then
        folds[#folds + 1] = { s, e }
        return
      end
      in_fn = in_fn or matches(type, M.config.function_pattern)
      for child in node:iter_children() do
        if child:named() then
          walk(child, in_fn)
        end
      end
    end
    -- The root itself never folds: that would hide the whole file.
    for child in root:iter_children() do
      if child:named() then
        walk(child, false)
      end
    end
  end)
  return folds
end

-- Unchanged lines of `winid`, in order. The k-th unchanged line of one side
-- of a diff is the counterpart of the k-th unchanged line of the other.
local function unchanged_lines(winid)
  local lines, index = {}, {}
  vim.api.nvim_win_call(winid, function()
    for l = 1, vim.fn.line("$") do
      if vim.fn.diff_hlID(l, 1) == 0 then
        lines[#lines + 1] = l
        index[l] = #lines
      end
    end
  end)
  return lines, index
end

local function set_folds(winid, folds)
  vim.api.nvim_win_call(winid, function()
    vim.wo.foldmethod = "manual"
    vim.cmd("normal! zE")
    for _, f in ipairs(folds) do
      vim.cmd(("%d,%dfold"):format(f[1], f[2]))
    end
    vim.wo.foldenable = true
    vim.wo.foldlevel = 0
  end)
end

-- Folds both sides of a two-way diff identically. Treesitter units are read
-- from one side only and mirrored onto the other through the unchanged-line
-- correspondence: folding each side from its own tree lets the two disagree
-- (different unit boundaries, a parser on one side only), and every
-- disagreement shifts the panes out of alignment. Returns false, leaving the
-- stock diff folds on both sides, when neither side has a parser.
function M.apply_pair(src, dst)
  local folds = compute(src)
  if not folds then
    src, dst = dst, src
    folds = compute(src)
    if not folds then
      return false
    end
  end

  local _, src_index = unchanged_lines(src)
  local dst_lines = unchanged_lines(dst)
  -- A fold without a counterpart is dropped from both sides, not just one.
  local kept, mirrored = {}, {}
  for _, f in ipairs(folds) do
    local ks, ke = src_index[f[1]], src_index[f[2]]
    if ks and ke and dst_lines[ke] then
      kept[#kept + 1] = f
      mirrored[#mirrored + 1] = { dst_lines[ks], dst_lines[ke] }
    end
  end

  set_folds(src, kept)
  set_folds(dst, mirrored)
  return true
end

return M
