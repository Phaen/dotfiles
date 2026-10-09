; Override of nvim-treesitter's php_only folds: function and method
; definitions fold together with the comment directly above them. The
; `prev-sibling-type?` predicate comes from lua/docfold.lua, which also
; explains why this file replaces the upstream one instead of extending it.
[
  (if_statement)
  (switch_statement)
  (while_statement)
  (do_statement)
  (for_statement)
  (foreach_statement)
  (try_statement)
  (class_declaration)
  (interface_declaration)
  (trait_declaration)
  (enum_declaration)
  (function_static_declaration)
  (namespace_use_declaration)+
  (array_creation_expression)
  (match_expression)
] @fold

; A definition folds from the start of the comment above it to its own end.
((comment) @fold . [(function_definition) (method_declaration)] @fold)

; A definition without a comment above it folds on its own; with one, the
; pattern above already covers it, and a second fold here would nest inside.
([(function_definition) (method_declaration)] @fold
  (#not-prev-sibling-type? @fold "comment"))
