return {
	{
		"nvim-telescope/telescope.nvim",
		keys = {
			{
				"<leader>gb",
				function()
					local builtin = require("telescope.builtin")
					local actions = require("telescope.actions")
					local action_state = require("telescope.actions.state")

					-- 1. Find the Git Root (to prevent crashes and ensure gh works)
					local buf = vim.api.nvim_get_current_buf()
					local filepath = vim.api.nvim_buf_get_name(buf)
					local filedir = vim.fn.fnamemodify(filepath, ":h")
					local git_root = vim.fn.system("git -C " .. filedir .. " rev-parse --show-toplevel"):gsub("%s+", "")

					if vim.v.shell_error ~= 0 then
						vim.notify("Not a git repository", vim.log.levels.ERROR)
						return
					end

					-- 2. Setup options for Line History
					local opts = {
						cwd = git_root,
						prompt_title = "Git Blame Line History",

						-- Default to current line
						from = vim.fn.line("."),
						to = vim.fn.line("."),

						attach_mappings = function(_, map)
							map({ "i", "n" }, "<CR>", function(prompt_bufnr)
								local selection = action_state.get_selected_entry()
								actions.close(prompt_bufnr)

								local sha = selection.value
								if not sha then
									return
								end

								vim.notify("Looking up PR for " .. sha:sub(1, 7) .. "...", vim.log.levels.INFO)

								-- 3. Logic: Try to find PR
								local cmd =
									string.format("gh pr list --search %s --state all --json url --jq '.[0].url'", sha)
								local handle = io.popen(cmd)
								local url = handle:read("*a")
								handle:close()

								url = url and url:gsub("%s+", "") or ""

								-- 4. Fallback: No PR found -> Open Commit
								if url == "" then
									vim.notify("No PR found. Opening Commit...", vim.log.levels.INFO)
									-- FIX: Removed broken Snacks call.
									-- We execute 'gh browse' inside the git_root to ensure it finds the correct repo.
									local browse_cmd = string.format("cd %s && gh browse %s", git_root, sha)
									os.execute(browse_cmd)
									return
								end

								-- 5. PR Found -> Open PR
								vim.notify("Opening PR: " .. url, vim.log.levels.INFO)
								local open_cmd = vim.fn.has("mac") == 1 and "open"
									or (vim.fn.has("win32") == 1 and "start" or "xdg-open")
								os.execute(string.format("%s '%s'", open_cmd, url))
							end)
							return true
						end,
					}

					-- Support Visual Mode
					local mode = vim.fn.mode()
					if mode == "v" or mode == "V" then
						opts.from = vim.fn.line("v")
						opts.to = vim.fn.line(".")
					end

					builtin.git_bcommits_range(opts)
				end,
				mode = { "n", "v" },
				desc = "Git Blame Line (Open PR)",
			},
		},
	},
}
