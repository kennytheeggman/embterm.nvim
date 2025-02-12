local embed = require('lua.embterm.embed')
local utils = require('lua.embterm.utils')
local sync = require('lua.embterm.sync')

function M.setup(start_row, end_row)
	local bufnr = vim.fn.bufnr()
	local ft = vim.bo.filetype
	local width = utils.win_get_size(bufnr).width
	local config1 = {
		cmd = function(win) vim.api.nvim_win_call(win, function() vim.cmd("set syntax="..ft) end) end,
		range = { start = start_row, last = end_row },
		width = width - math.floor(width / 2) - 4,
		col = math.floor(width / 2) + 4,
		anchor = 'NW'
	}
	local config2 = {
		cmd = function(win) vim.api.nvim_win_call(win, function() vim.cmd("set syntax="..ft) end) end,
		range = { start = start_row, last = end_row },
		width = math.floor(width / 2),
		col = 0,
		anchor = 'NW'
	}
	local emb1 = embed.new(bufnr, config1)
	local emb2 = embed.new(bufnr, config2)
	emb1.update()
	emb2.update()
	local syn = sync.new(emb2.bufnr, bufnr, start_row, end_row)
end

return M
