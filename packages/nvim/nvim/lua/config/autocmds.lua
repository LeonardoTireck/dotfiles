-- Autocmds are automatically loaded on the VeryLazy event
-- Default autocmds that are always set: https://github.com/LazyVim/LazyVim/blob/main/lua/lazyvim/config/autocmds.lua
--
-- Add any additional autocmds here
-- with `vim.api.nvim_create_autocmd`
--
-- Or remove existing autocmds by their group name (which is prefixed with `lazyvim_` for the defaults)
-- e.g. vim.api.nvim_del_augroup_by_name("lazyvim_wrap_spell")
--

-- Run ESLint auto-fix on save (only when eslint LSP is attached)
vim.api.nvim_create_autocmd("BufWritePre", {
  pattern = { "*.js", "*.jsx", "*.ts", "*.tsx", "*.vue", "*.svelte" },
  callback = function(event)
    local bufnr = event.buf
    local get_clients = vim.lsp.get_clients or vim.lsp.get_active_clients
    if #get_clients({ bufnr = bufnr, name = "eslint" }) == 0 then return end

    local params = vim.lsp.util.make_range_params(nil, "utf-8")
    params.context = { only = { "source.fixAll.eslint" }, diagnostics = {} }

    local result = vim.lsp.buf_request_sync(bufnr, "textDocument/codeAction", params, 3000)
    for _, res in pairs(result or {}) do
      for _, action in pairs(res.result or {}) do
        if action.edit then
          vim.lsp.util.apply_workspace_edit(action.edit, "utf-8")
        end
      end
    end
  end,
})
