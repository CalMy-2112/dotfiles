-- Options are automatically loaded before lazy.nvim startup
-- Default options that are always set: https://github.com/LazyVim/LazyVim/blob/main/lua/lazyvim/config/options.lua
-- Add any additional options here
vim.g.python3_host_prog = vim.fn.expand("~/.virtualenvs/neovim/bin/python3")
if (vim.env.XDG_CURRENT_DESKTOP or ""):find("GNOME") and vim.fn.executable("xclip") == 1 then
  vim.g.clipboard = {
    name = "xclip (GNOME)",
    copy = {
      ["+"] = { "xclip", "-quiet", "-i", "-selection", "clipboard" },
      ["*"] = { "xclip", "-quiet", "-i", "-selection", "primary" },
    },
    paste = {
      ["+"] = { "xclip", "-o", "-selection", "clipboard" },
      ["*"] = { "xclip", "-o", "-selection", "primary" },
    },
    cache_enabled = 1,
  }
end
