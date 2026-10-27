return {
  {
    "scalameta/nvim-metals",
    config = function(_, metals_config)
      vim.api.nvim_create_autocmd("FileType", {
        group = vim.api.nvim_create_augroup("nvim-metals", { clear = true }),
        pattern = { "scala", "sbt" },
        callback = function()
          require("metals").initialize_or_attach(metals_config)
        end,
      })
    end,
  },
}
