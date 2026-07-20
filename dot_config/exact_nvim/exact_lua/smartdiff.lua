-- smartdiff: a 'diffexpr' bridge that fixes nonsense line pairing in diff mode.
--
-- Nvim's built-in `linematch` pairs lines within a hunk by raw character
-- edit distance with no similarity floor, so an unrelated pair like
-- `])->toArray();` / `$offerStats = $model->getOfferStats();` gets shown as
-- a "changed" line instead of a delete + add. This module replaces hunk
-- generation with a tiered engine that only pairs genuinely similar lines:
--
--   tier 1  difftastic (AST-aware, per-language allowlist, needs `difft`
--           on $PATH; uses its unstable JSON interface, DFT_UNSTABLE=yes)
--   tier 2  vim.text.diff (git's xdiff) + a token-similarity pairing pass
--           with a threshold — language-agnostic
--   tier 3  raw vim.text.diff output (identical to diff mode without
--           linematch) — cannot fail
--
-- Every tier degrades silently into the next; worst case equals stock
-- behavior. Inspect with :SmartDiffStatus.
--
-- DELETE ME when nvim gains a native linematch similarity threshold
-- (watch neovim/neovim for `linematch` options beyond the line-count cap).
-- Removal: delete this file and the smartdiff lines in lua/config/options.lua.
--
-- Kill switches (no restart needed):
--   vim.g.smartdiff_enabled = false  -- passthrough to tier 3
--   vim.g.smartdiff_difft = false    -- skip tier 1

local M = {}

M.config = {
  -- Minimum token-set similarity (0..1) for two lines to pair as "changed".
  threshold = 0.3,
  -- Per-hunk line-count cap for the tier-2 pairing pass (same idea as
  -- linematch:{n}); larger hunks pass through unpaired.
  max_hunk_lines = 200,
  difft = {
    timeout_ms = 2000,
    max_bytes = 1024 * 1024,
    -- Buffer filetype -> difft language name (difft --list-languages).
    -- Allowlist on purpose: mixed-grammar filetypes (vue, blade, ...) fall
    -- through to tier 2, which is syntax-blind and handles them fine.
    languages = {
      bash = "Bash", sh = "Bash", c = "C", clojure = "Clojure",
      cmake = "CMake", cpp = "C++", cs = "C#", css = "CSS", dart = "Dart",
      elixir = "Elixir", erlang = "Erlang", go = "Go", haskell = "Haskell",
      html = "HTML", java = "Java", javascript = "JavaScript",
      javascriptreact = "JavaScript JSX", json = "JSON", jsonc = "JSON",
      julia = "Julia", kotlin = "Kotlin", lua = "Lua", make = "Make",
      nix = "Nix", ocaml = "OCaml", perl = "Perl", php = "PHP",
      proto = "Proto", python = "Python", r = "R", ruby = "Ruby",
      rust = "Rust", scala = "Scala", scss = "SCSS", sql = "SQL",
      swift = "Swift", tex = "LaTeX", toml = "TOML",
      typescript = "TypeScript", typescriptreact = "TypeScript TSX",
      xml = "XML", yaml = "YAML", zig = "Zig",
    },
  },
}

-- Diagnostics for :SmartDiffStatus.
M.state = { last_tier = nil, last_error = nil, difft_available = nil }

local xdiff = vim.text and vim.text.diff or vim.diff

local function difft_available()
  if M.state.difft_available == nil then
    M.state.difft_available = vim.fn.executable("difft") == 1
  end
  return M.state.difft_available
end

-- 'diffopt' flags relevant to comparison, read live so scoped changes
-- (e.g. diffview toggling iwhiteall) are honored per invocation.
local function diffopt_flags()
  local o = "," .. vim.o.diffopt .. ","
  return {
    icase = o:find(",icase,", 1, true) ~= nil,
    iwhiteall = o:find(",iwhiteall,", 1, true) ~= nil,
    iwhite = o:find(",iwhite,", 1, true) ~= nil,
    iwhiteeol = o:find(",iwhiteeol,", 1, true) ~= nil,
    iblank = o:find(",iblank,", 1, true) ~= nil,
    indent_heuristic = o:find(",indent-heuristic,", 1, true) ~= nil,
    algorithm = o:match("algorithm:(%a+)") or "myers",
  }
end

local function normalize(line, flags)
  if flags.icase then line = line:lower() end
  if flags.iwhiteall then
    line = line:gsub("%s+", "")
  elseif flags.iwhite then
    line = line:gsub("%s+", " "):gsub("^ ", ""):gsub(" $", "")
  elseif flags.iwhiteeol then
    line = line:gsub("%s+$", "")
  end
  return line
end

-- ---------------------------------------------------------------------------
-- Ops model shared by all tiers: a list of
--   {type = "same"|"change"|"del"|"add", ai = old lnum, bi = new lnum}
-- in file order (1-based, absolute). The emitter below turns runs of
-- non-"same" ops into ed-style hunks; paired-but-dissimilar lines never
-- exist as an op type, so vim can never render a nonsense pairing.
-- ---------------------------------------------------------------------------

local function range_fmt(s, e)
  return s == e and tostring(s) or (s .. "," .. e)
end

-- Turns ops into classic ed-style diff lines. A maximal run of "change"
-- ops becomes one NcN hunk (always 1:1 by construction); a maximal run of
-- del/add ops becomes a delete hunk and/or an add hunk.
local function emit(ops, a_lines, b_lines, out)
  local i, n = 1, #ops
  while i <= n do
    local op = ops[i]
    if op.type == "same" then
      i = i + 1
    elseif op.type == "change" then
      local j = i
      while j < n and ops[j + 1].type == "change" do j = j + 1 end
      out[#out + 1] = range_fmt(ops[i].ai, ops[j].ai) .. "c" .. range_fmt(ops[i].bi, ops[j].bi)
      for k = i, j do out[#out + 1] = "< " .. a_lines[ops[k].ai] end
      out[#out + 1] = "---"
      for k = i, j do out[#out + 1] = "> " .. b_lines[ops[k].bi] end
      i = j + 1
    else
      local j, dels, adds = i, {}, {}
      while j <= n and (ops[j].type == "del" or ops[j].type == "add") do
        if ops[j].type == "del" then dels[#dels + 1] = ops[j].ai else adds[#adds + 1] = ops[j].bi end
        j = j + 1
      end
      -- Within a maximal del/add segment the old and new line numbers are
      -- each contiguous. Touching delete+add hunks must never be emitted:
      -- vim merges them into one unequal change block and runs linematch
      -- over it, reintroducing the nonsense pairing this module exists to
      -- prevent. Instead, pair the first min(n,m) lines positionally as an
      -- equal-sized change hunk and emit only the remainder as a pure
      -- delete or add — shapes vim keeps separate.
      local nd, na = #dels, #adds
      local k = math.min(nd, na)
      if k > 0 then
        out[#out + 1] = range_fmt(dels[1], dels[k]) .. "c" .. range_fmt(adds[1], adds[k])
        for x = 1, k do out[#out + 1] = "< " .. a_lines[dels[x]] end
        out[#out + 1] = "---"
        for x = 1, k do out[#out + 1] = "> " .. b_lines[adds[x]] end
      end
      if nd > k then
        local after_b = na > 0 and adds[na] or ops[i].bi
        out[#out + 1] = range_fmt(dels[k + 1], dels[nd]) .. "d" .. after_b
        for x = k + 1, nd do out[#out + 1] = "< " .. a_lines[dels[x]] end
      elseif na > k then
        local after_a = nd > 0 and dels[nd] or ops[i].ai
        out[#out + 1] = after_a .. "a" .. range_fmt(adds[k + 1], adds[na])
        for x = k + 1, na do out[#out + 1] = "> " .. b_lines[adds[x]] end
      end
      i = j
    end
  end
end

-- ---------------------------------------------------------------------------
-- Tier 2: token-similarity pairing within xdiff hunks
-- ---------------------------------------------------------------------------

local function token_set(line, flags)
  if flags.icase then line = line:lower() end
  local set, count = {}, 0
  for tok in line:gmatch("[%w_]+") do
    if not set[tok] then
      set[tok] = true
      count = count + 1
    end
  end
  return { set = set, count = count, stripped = (line:gsub("%s+", "")) }
end

local function similarity(a, b)
  if a.count == 0 and b.count == 0 then
    return a.stripped == b.stripped and 1 or 0
  end
  if a.count == 0 or b.count == 0 then return 0 end
  local inter = 0
  local small, large = a, b
  if b.count < a.count then small, large = b, a end
  for tok in pairs(small.set) do
    if large.set[tok] then inter = inter + 1 end
  end
  return inter / (a.count + b.count - inter)
end

-- Needleman-Wunsch-style alignment maximizing total similarity; pairing
-- below the threshold is impossible, gaps are free. Returns ops for one hunk.
-- Pairs whose content is identical under 'diffopt' flags come back as "same"
-- ops — they act as block separators, which matters because vim merges
-- touching diff blocks and re-pairs inside them (see emit).
local function pair_hunk(a_lines, b_lines, sa, ca, sb, cb, flags, ops)
  local ta, tb = {}, {}
  for i = 1, ca do ta[i] = token_set(a_lines[sa + i - 1], flags) end
  for j = 1, cb do tb[j] = token_set(b_lines[sb + j - 1], flags) end

  local th = M.config.threshold
  local dp = {}
  for i = 0, ca do
    dp[i] = {}
    dp[i][0] = 0
  end
  for j = 1, cb do dp[0][j] = 0 end
  for i = 1, ca do
    for j = 1, cb do
      local best = math.max(dp[i - 1][j], dp[i][j - 1])
      local sim = similarity(ta[i], tb[j])
      if sim >= th and dp[i - 1][j - 1] + sim > best then
        best = dp[i - 1][j - 1] + sim
      end
      dp[i][j] = best
    end
  end

  -- Traceback prefers gap moves over pairing on ties, so equal-score
  -- alignments resolve to the leftmost pairing (re-anchoring a trailing
  -- context line to the first of several identical candidates).
  local rev = {}
  local i, j = ca, cb
  while i > 0 or j > 0 do
    if j > 0 and (i == 0 or dp[i][j] == dp[i][j - 1]) then
      -- bi/ai on gap ops hold the "after this line" anchor in the other file.
      rev[#rev + 1] = { type = "add", ai = sa + i - 1, bi = sb + j - 1 }
      j = j - 1
    elseif i > 0 and (j == 0 or dp[i][j] == dp[i - 1][j]) then
      rev[#rev + 1] = { type = "del", ai = sa + i - 1, bi = sb + j - 1 }
      i = i - 1
    else
      local ai, bi = sa + i - 1, sb + j - 1
      local same = normalize(a_lines[ai], flags) == normalize(b_lines[bi], flags)
      rev[#rev + 1] = { type = same and "same" or "change", ai = ai, bi = bi }
      i, j = i - 1, j - 1
    end
  end
  for k = #rev, 1, -1 do ops[#ops + 1] = rev[k] end
end

local function tier2(a_lines, b_lines, flags)
  local hunks = xdiff(table.concat(a_lines, "\n") .. "\n", table.concat(b_lines, "\n") .. "\n", {
    result_type = "indices",
    algorithm = flags.algorithm,
    indent_heuristic = flags.indent_heuristic,
    ignore_whitespace = flags.iwhiteall,
    ignore_whitespace_change = flags.iwhite,
    ignore_whitespace_change_at_eol = flags.iwhiteeol,
    ignore_blank_lines = flags.iblank,
  })
  -- xdiff freely emits touching hunks, and vim merges touching diff blocks
  -- back into one before rendering — so pairing must operate on the merged
  -- unit. Group hunks into regions of half-open intervals [a1,a2) x [b1,b2),
  -- fusing hunks that touch on both sides.
  local regions = {}
  for _, h in ipairs(hunks) do
    local a1 = h[2] > 0 and h[1] or h[1] + 1
    local b1 = h[4] > 0 and h[3] or h[3] + 1
    local r = regions[#regions]
    if r and a1 == r.a2 and b1 == r.b2 then
      r.a2, r.b2 = a1 + h[2], b1 + h[4]
    else
      regions[#regions + 1] = { a1 = a1, a2 = a1 + h[2], b1 = b1, b2 = b1 + h[4] }
    end
  end

  local out = {}
  for ri, r in ipairs(regions) do
    local sa, ca, sb, cb = r.a1, r.a2 - r.a1, r.b1, r.b2 - r.b1
    local ops = {}
    if ca == 0 then
      for j = 0, cb - 1 do ops[#ops + 1] = { type = "add", ai = sa - 1, bi = sb + j } end
      emit(ops, a_lines, b_lines, out)
    elseif cb == 0 then
      for i = 0, ca - 1 do ops[#ops + 1] = { type = "del", ai = sa + i, bi = sb - 1 } end
      emit(ops, a_lines, b_lines, out)
    elseif ca + cb > M.config.max_hunk_lines then
      -- Too large to pair; emit as-is (positional pairing, like stock vim
      -- when a hunk exceeds linematch:{n}).
      out[#out + 1] = range_fmt(sa, sa + ca - 1) .. "c" .. range_fmt(sb, sb + cb - 1)
      for i = sa, sa + ca - 1 do out[#out + 1] = "< " .. a_lines[i] end
      out[#out + 1] = "---"
      for j = sb, sb + cb - 1 do out[#out + 1] = "> " .. b_lines[j] end
    else
      -- Extend the alignment one same-line beyond each side of the region
      -- (when the gap to the neighboring region allows). xdiff can anchor
      -- a context line like a closing `}` to the wrong one of several
      -- identical candidates, gluing a change block to an add block; the
      -- DP re-anchors it to the leftmost copy, where it becomes a "same"
      -- separator between blocks.
      local prev, nxt = regions[ri - 1], regions[ri + 1]
      local ext_pre = (sa > (prev and prev.a2 or 1) and sb > (prev and prev.b2 or 1)) and 1 or 0
      local ext_post = (r.a2 <= #a_lines and r.b2 <= #b_lines
        and r.a2 < (nxt and nxt.a1 or math.huge) and r.b2 < (nxt and nxt.b1 or math.huge)) and 1 or 0
      pair_hunk(a_lines, b_lines,
        sa - ext_pre, ca + ext_pre + ext_post,
        sb - ext_pre, cb + ext_pre + ext_post, flags, ops)
      emit(ops, a_lines, b_lines, out)
    end
  end
  return out
end

-- ---------------------------------------------------------------------------
-- Tier 1: difftastic
-- ---------------------------------------------------------------------------

-- The temp files vim hands to 'diffexpr' have no extension, so difft cannot
-- detect the language; recover it from the diff-mode windows in the current
-- tab. Returns a difft language name, or nil to fall through to tier 2.
local function difft_language()
  local lang = nil
  for _, win in ipairs(vim.api.nvim_tabpage_list_wins(0)) do
    if vim.wo[win].diff then
      local ft = vim.bo[vim.api.nvim_win_get_buf(win)].filetype
      if ft ~= "" then
        local l = M.config.difft.languages[ft]
        if l == nil or (lang ~= nil and lang ~= l) then return nil end
        lang = l
      end
    end
  end
  return lang
end

local function tier1(fname_a, fname_b, a_lines, b_lines, flags)
  if vim.g.smartdiff_difft == false or not difft_available() then return nil end
  local lang = difft_language()
  if not lang then return nil end
  if vim.fn.getfsize(fname_a) > M.config.difft.max_bytes
      or vim.fn.getfsize(fname_b) > M.config.difft.max_bytes then
    return nil
  end

  local res = vim.system(
    { "difft", "--display", "json", "--override", "*:" .. lang, fname_a, fname_b },
    { env = { DFT_UNSTABLE = "yes" }, timeout = M.config.difft.timeout_ms }
  ):wait()
  if res.code ~= 0 or not res.stdout or res.stdout == "" then
    M.state.last_error = ("difft exit %s: %s"):format(res.code, (res.stderr or ""):sub(1, 200))
    return nil
  end

  local ok, doc = pcall(vim.json.decode, res.stdout)
  if not ok or type(doc) ~= "table" then
    M.state.last_error = "difft JSON parse failed (unstable interface changed?)"
    return nil
  end
  if doc.status == "unchanged" then return {} end
  local rows = doc.aligned_lines
  if type(rows) ~= "table" then
    M.state.last_error = "difft JSON missing aligned_lines (unstable interface changed?)"
    return nil
  end

  -- Convert 0-based aligned rows to ops, validating that difft's alignment
  -- is a monotonic, complete cover of both files — anything else (moved
  -- code, format drift) falls through to tier 2.
  local ops = {}
  local expect_a, expect_b = 1, 1
  for _, row in ipairs(rows) do
    local ra, rb = row[1], row[2]
    local ai = ra ~= vim.NIL and ra ~= nil and ra + 1 or nil
    local bi = rb ~= vim.NIL and rb ~= nil and rb + 1 or nil
    if ai and ai > #a_lines then ai = nil end
    if bi and bi > #b_lines then bi = nil end
    if ai or bi then
      if (ai and ai ~= expect_a) or (bi and bi ~= expect_b) then return nil end
      if ai and bi then
        local same = normalize(a_lines[ai], flags) == normalize(b_lines[bi], flags)
        ops[#ops + 1] = { type = same and "same" or "change", ai = ai, bi = bi }
        expect_a, expect_b = ai + 1, bi + 1
      elseif ai then
        ops[#ops + 1] = { type = "del", ai = ai, bi = expect_b - 1 }
        expect_a = ai + 1
      else
        ops[#ops + 1] = { type = "add", ai = expect_a - 1, bi = bi }
        expect_b = bi + 1
      end
    end
  end
  if expect_a ~= #a_lines + 1 or expect_b ~= #b_lines + 1 then return nil end

  local out = {}
  emit(ops, a_lines, b_lines, out)
  return out
end

-- ---------------------------------------------------------------------------
-- Entry points
-- ---------------------------------------------------------------------------

-- Core computation, separated from the v: plumbing for testability.
function M.compute(fname_a, fname_b)
  local a_lines = vim.fn.readfile(fname_a)
  local b_lines = vim.fn.readfile(fname_b)
  local flags = diffopt_flags()

  if vim.g.smartdiff_enabled ~= false then
    local ok, out = pcall(tier1, fname_a, fname_b, a_lines, b_lines, flags)
    if ok and out then
      M.state.last_tier = 1
      return out
    end
    if not ok then M.state.last_error = tostring(out) end

    ok, out = pcall(tier2, a_lines, b_lines, flags)
    if ok then
      M.state.last_tier = 2
      return out
    end
    M.state.last_error = tostring(out)
  end

  M.state.last_tier = 3
  local raw = xdiff(table.concat(a_lines, "\n") .. "\n", table.concat(b_lines, "\n") .. "\n", {
    result_type = "indices",
    algorithm = flags.algorithm,
  })
  local out = {}
  for _, h in ipairs(raw) do
    local sa, ca, sb, cb = h[1], h[2], h[3], h[4]
    if ca == 0 then
      out[#out + 1] = sa .. "a" .. range_fmt(sb, sb + cb - 1)
      for j = sb, sb + cb - 1 do out[#out + 1] = "> " .. b_lines[j] end
    elseif cb == 0 then
      out[#out + 1] = range_fmt(sa, sa + ca - 1) .. "d" .. sb
      for i = sa, sa + ca - 1 do out[#out + 1] = "< " .. a_lines[i] end
    else
      out[#out + 1] = range_fmt(sa, sa + ca - 1) .. "c" .. range_fmt(sb, sb + cb - 1)
      for i = sa, sa + ca - 1 do out[#out + 1] = "< " .. a_lines[i] end
      out[#out + 1] = "---"
      for j = sb, sb + cb - 1 do out[#out + 1] = "> " .. b_lines[j] end
    end
  end
  return out
end

function M.diffexpr()
  local ok, out = pcall(M.compute, vim.v.fname_in, vim.v.fname_new)
  if not ok then
    M.state.last_error = tostring(out)
    M.state.last_tier = 3
    out = {}
  end
  vim.fn.writefile(out, vim.v.fname_out)
end

function M.setup()
  vim.opt.diffexpr = "v:lua.require'smartdiff'.diffexpr()"
  vim.api.nvim_create_user_command("SmartDiffStatus", function()
    local tiers = {
      [1] = "tier 1 (difftastic)",
      [2] = "tier 2 (xdiff + token pairing)",
      [3] = "tier 3 (raw xdiff passthrough)",
    }
    local difft = not difft_available() and "not installed (tier 1 dormant)"
        or vim.g.smartdiff_difft == false and "installed, disabled"
        or "installed, enabled"
    local lines = {
      "smartdiff:   " .. (vim.g.smartdiff_enabled ~= false and "enabled" or "disabled (passthrough)"),
      "difftastic:  " .. difft,
      "last diff:   " .. (tiers[M.state.last_tier] or "none run yet"),
      "last error:  " .. (M.state.last_error or "none"),
    }
    vim.notify(table.concat(lines, "\n"), vim.log.levels.INFO, { title = "smartdiff" })
  end, {})
end

return M
