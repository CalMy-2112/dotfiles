-- Autocmds are automatically loaded on the VeryLazy event
-- Default autocmds that are always set: https://github.com/LazyVim/LazyVim/blob/main/lua/lazyvim/config/autocmds.lua
--
-- Add any additional autocmds here
-- with `vim.api.nvim_create_autocmd`
--
-- Or remove existing autocmds by their group name (which is prefixed with `lazyvim_` for the defaults)
-- e.g. vim.api.nvim_del_augroup_by_name("lazyvim_wrap_spell")

local swank_port = 4005

local function swank_running()
  local check = string.format(
    "bash -c 'exec 3<>/dev/tcp/127.0.0.1/%d' 2>/dev/null && echo yes || echo no",
    swank_port
  )
  return vim.fn.system(check):match("yes") ~= nil
end

vim.api.nvim_create_autocmd("FileType", {
  pattern = "lisp",
  callback = function()
    if not swank_running() then
      vim.notify("Starting Swank server…", vim.log.levels.INFO)
      vim.fn.jobstart({
        "sbcl", "--non-interactive",
        "--eval", "(ql:quickload :swank)",
        "--eval", "(swank:create-server :dont-close t)",
        "--eval", "(loop (sleep 3600))",
      }, { detach = true })
    end
  end,
})

