-- Keymaps are automatically loaded on the VeryLazy event
-- Default keymaps that are always set: https://github.com/LazyVim/LazyVim/blob/main/lua/lazyvim/config/keymaps.lua
-- Add any additional keymaps here

-- Maps leader cp to copy file name
vim.keymap.set("n", "cp", "<cmd> let @+ = expand('%:.')<CR>", { desc = "Copy file name" })

-- Maps jj to ESC in normal mode
vim.keymap.set("i", "jj", "<ESC>", { silent = true })

-- Replace the word cursor is on globally
vim.keymap.set("n", "<leader>r", function()
	vim.lsp.buf.rename()
end, { desc = "Replace word cursor is on globally" })
