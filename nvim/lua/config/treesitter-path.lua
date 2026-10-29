-- Guix patches Neovim (neovim-tree-sitter-grammar-path.patch).
-- With that patch, vim.treesitter.language.add() looks for parsers ONLY in
-- $TREE_SITTER_GRAMMAR_PATH (libtree-sitter-<lang>.so), not in "parser/" on
-- the runtimepath, where nvim-treesitter installs them.
-- This wrapper searches "parser/<lang>.*" on the runtimepath first (normal
-- Neovim behavior), then falls back to the Guix search.
local language = require("vim.treesitter.language")
local original_add = language.add

language.add = function(lang, opts)
  opts = opts or {}
  if opts.path == nil and type(lang) == "string" then
    local name = lang:lower()
    if vim._ts_has_language and vim._ts_has_language(name) then
      return true
    end
    if name:match("^[%w_]+$") then
      local found = vim.api.nvim_get_runtime_file("parser/" .. name .. ".*", false)[1]
      if found then
        return original_add(lang, vim.tbl_extend("force", opts, { path = found }))
      end
    end
  end
  return original_add(lang, opts)
end
