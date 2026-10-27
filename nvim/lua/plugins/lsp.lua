return {
  {
    "neovim/nvim-lspconfig",
    opts = {
      servers = {
        nixd = {},
        clangd = {},
        gopls = {},
        pyright = {},
        bashls = {
          filetypes = { "sh", "bash", "zsh" },
        },
        hls = {
          settings = {
            haskell = {
              formattingProvider = "stylish-haskell",
              plugin = {
                semanticTokens = {
                  globalOn = true,
                },
              },
            },
          },
        },
        asm_lsp = {},
        sqls = {},
        ts_ls = {},
      },
    },
  },
  {
    "mason-org/mason-lspconfig.nvim",
    enabled = false,
  },
  {
    "mason-org/mason.nvim",
    enabled = false,
  },
  {
    "mrcjkb/rustaceanvim",
    version = "^6",
    lazy = false,
    init = function()
      vim.g.rustaceanvim = {
        server = {
          default_settings = {
            ["rust-analyzer"] = {
              lens = {
                enable = true,
                debug = { enable = true },
                implementations = { enable = true },
                run = { enable = true },
                updateTest = { enable = true },
                references = {
                  adt = { enable = true },
                  enumVariant = { enable = true },
                  method = { enable = true },
                  trait = { enable = true },
                },
              },
            },
          },
        },
      }
    end,
  },
}
