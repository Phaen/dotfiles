-- docfold: fold a function together with the comment above it.
--
-- The stock treesitter folds start at the `function` line, so a closed fold
-- leaves the docblock above it dangling in full. Folding the docblock in with
-- its definition hides the pair as one line, which is what a collapsed
-- method should look like.
--
-- Neovim's treesitter foldexpr already spans a fold across several nodes:
-- when one `@fold` capture matches more than one node in a pattern, the fold
-- runs from the first node's start to the last node's end. So a query pattern
-- like `((comment) @fold . (method_declaration) @fold)` does the whole job.
-- What tree-sitter lacks is the negative half: a plain
-- `(method_declaration) @fold` for undocumented methods also matches the
-- documented ones, nesting a second fold inside the first. The
-- `prev-sibling-type?` predicate registered here fills that gap; a query
-- uses the `not-` form that Neovim derives from it.
--
-- Per-language queries live in queries/<lang>/folds.scm. Each one is a full
-- override of the upstream file with the definition nodes moved out of the
-- base list into the two patterns below; see queries/php_only/folds.scm.
-- Overriding, not extending, matters: an `; extends` file cannot remove the
-- plain definition fold from the base list. Mind that nvim-treesitter's
-- `queries/php/folds.scm` is only `; inherits: php_only`, and Neovim treats
-- inherit files as extensions, so the override has to be placed under the
-- inherited language (php_only) to replace the base query.
--
-- Adding a language: copy its upstream folds.scm from
-- ~/.local/share/nvim/lazy/nvim-treesitter/runtime/queries/<lang>/, drop
-- the function/method node types from the base list, and append:
--
--   ((comment) @fold . [(function_definition) (method_declaration)] @fold)
--   ([(function_definition) (method_declaration)] @fold
--     (#not-prev-sibling-type? @fold "comment"))
--
-- Any comment directly above the definition is taken, not just docblocks;
-- a `//` line that documents the method belongs with it just as much.
--
-- setup() must run before the first query is parsed, which lazy.nvim's
-- plugin loading triggers; lua/config/options.lua calls it in time.

local M = {}

-- `(#prev-sibling-type? @capture "type" ...)`: true when the captured node's
-- previous named sibling is of one of the given node types.
local function prev_sibling_type(match, _, _, predicate)
  local nodes = match[predicate[2]]
  if not nodes or not nodes[1] then
    return false
  end
  local prev = nodes[1]:prev_named_sibling()
  return prev ~= nil and vim.list_contains(vim.list_slice(predicate, 3), prev:type())
end

function M.setup()
  vim.treesitter.query.add_predicate("prev-sibling-type?", prev_sibling_type, { force = true, all = true })
end

return M
