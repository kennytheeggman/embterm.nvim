local M = {}

local term = require("embterm.term")

local config

function M.quick_setup()
	M.setup({
		cmd="bash",
		keybinds={
			{ "n", "<C-i>f", "<cmd>EmbTermFocus<cr>" },
			{ "t", "<C-i>f", "<cmd>EmbTermDefocus<cr>" },
			{ "n", "<C-i>i", "<cmd>EmbTermOpen<cr>" },
		},
		mark={
			start="<",
			last=">",
		},
		priv={
			start="8",
			last="9",
		}
	})
end

function M.setup(conf)
	config = conf
	term.setup(config)
	term.disable()
	vim.api.nvim_create_user_command("EmbTermOpen", M.term, {})
	vim.api.nvim_create_user_command("EmbTermFocus", M.focus, {})
	vim.api.nvim_create_user_command("EmbTermDefocus", M.defocus, {})
	vim.api.nvim_create_user_command("EmbTermClose", M.close, {})
	local keybinds = conf.keybinds
	for _, v in ipairs(keybinds) do
		vim.api.nvim_set_keymap(v[1], v[2], v[3], { noremap = true })
	end
end

function M.term()
	local bufnr = vim.fn.getwininfo()[vim.fn.winnr()].bufnr
	local start = vim.api.nvim_buf_get_mark(bufnr, config.mark.start)
	local last = vim.api.nvim_buf_get_mark(bufnr, config.mark.last)
	vim.api.nvim_buf_set_mark(bufnr, config.priv.start, start[1], start[2], {})
	vim.api.nvim_buf_set_mark(bufnr, config.priv.last, last[1], last[2], {})
	if not term.enabled then
		term.setup(config)
		term.enable()
	end
end
function M.close()
	term.disable()
end

function M.focus()
	term.focus()
end
function M.defocus()
	term.defocus()
end

return M
