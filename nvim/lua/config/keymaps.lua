-- Keymaps are automatically loaded on the VeryLazy event
-- Default keymaps that are always set: https://github.com/LazyVim/LazyVim/blob/main/lua/lazyvim/config/keymaps.lua
-- Add any additional keymaps here
--


local function list_floats()
  local out = {}
  for _, win in ipairs(vim.api.nvim_list_wins()) do
    local ok, cfg = pcall(vim.api.nvim_win_get_config, win)
    if ok and cfg.relative ~= "" then
      local buf = vim.api.nvim_win_get_buf(win)
      table.insert(out, string.format("win=%d buf=%d ft=%s lines=%d",
        win, buf, vim.bo[buf].filetype, vim.api.nvim_buf_line_count(buf)))
    end
  end
  return out
end

vim.keymap.set("i", "<C-k>", function()
  local blink = require("blink.cmp")
  vim.notify("BEFORE: " .. vim.inspect(list_floats()), vim.log.levels.INFO)
  if blink.is_signature_visible() then
    blink.hide_signature()
    for _, win in ipairs(vim.api.nvim_list_wins()) do
      if vim.api.nvim_win_get_config(win).relative ~= "" then
        pcall(vim.api.nvim_win_close, win, false)
      end
    end
  else
    blink.show_signature()
  end
  vim.defer_fn(function()
    vim.notify("AFTER: " .. vim.inspect(list_floats()), vim.log.levels.INFO)
  end, 50)
end, { desc = "Toggle signature help (debug)" })
