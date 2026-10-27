-- Run the cell between the "# %%" markers around the cursor.
local function run_cell()
  local top = vim.fn.search("^# %%", "bcnW") -- marker above the cursor, 0 if none
  local nxt = vim.fn.search("^# %%", "nW")   -- next marker, 0 if none
  local first = top + 1
  local last = nxt == 0 and vim.fn.line("$") or nxt - 1
  if first <= last then
    vim.fn.MoltenEvaluateRange(first, last)
  end
end

-- A minimum notebook that jupytext.nvim can read.
local notebook_template = [[
{
 "cells": [
  {"cell_type": "code", "execution_count": null, "metadata": {}, "outputs": [], "source": []}
 ],
 "metadata": {
  "kernelspec": {"display_name": "Python 3", "language": "python", "name": "python3"},
  "language_info": {"name": "python"}
 },
 "nbformat": 4,
 "nbformat_minor": 4
}
]]

-- :NewNotebook name  ->  writes name.ipynb, then opens it.
local function new_notebook(cmd)
  local path = (cmd.args:gsub("%.ipynb$", "")) .. ".ipynb"
  if vim.fn.filereadable(path) == 1 then
    vim.notify(path .. " exists already", vim.log.levels.ERROR)
    return
  end
  local file = assert(io.open(path, "w"))
  file:write(notebook_template)
  file:close()
  vim.cmd.edit(vim.fn.fnameescape(path))
end

return {
  {
    "GCBallesteros/jupytext.nvim",
    lazy = false,
    opts = { style = "hydrogen" },
    init = function()
      vim.api.nvim_create_user_command("NewNotebook", new_notebook, { nargs = 1, complete = "file" })
    end,
  },
  {
    "benlubas/molten-nvim",
    version = "^1.0.0",
    lazy = false,
    build = ":UpdateRemotePlugins",
    init = function()
      vim.g.molten_virt_text_output = true
      vim.g.molten_auto_open_output = false
      vim.g.molten_wrap_output = true
    end,
    keys = {
      { "<leader>ji", "<cmd>MoltenInit<cr>", desc = "Jupyter: start kernel" },
      { "<leader>jc", run_cell, desc = "Jupyter: run cell" },
      { "<leader>jl", "<cmd>MoltenEvaluateLine<cr>", desc = "Jupyter: run line" },
      { "<leader>jv", ":<C-u>MoltenEvaluateVisual<cr>gv", mode = "v", desc = "Jupyter: run selection" },
      { "<leader>jo", "<cmd>noautocmd MoltenEnterOutput<cr>", desc = "Jupyter: open output" },
      { "<leader>jx", "<cmd>MoltenInterrupt<cr>", desc = "Jupyter: interrupt kernel" },
    },
  },
}
