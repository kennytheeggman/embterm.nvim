local utils = require('lua.embterm.utils')
local text = require('lua.embterm.sync')

local M = {}
M.text = text

function M.new(parent, config)
	local O = {}
	O.pbufnr = parent
	O.cmd = config.cmd
	O.selection = config.range
	-- asserts
	assert(O.pbufnr ~= nil, "Embterm: parent should not be nil")
	assert(O.cmd ~= nil, "Embterm: config.cmd should not be nil")
	assert(O.selection ~= nil, "Embterm: config.range should not be nil")

	O.bufnr = vim.api.nvim_create_buf(false, true)
	O.autocmds = {}

	function O.delete()
		-- delete windows
		utils.win_remove(O.bufnr)
		-- delete buffer
		if vim.api.nvim_buf_is_valid(O.bufnr) then
			vim.api.nvim_buf_delete(O.bufnr, { force = true })
		end
		-- delete autocmds
		for _, autocmd in ipairs(O.autocmds) do
			vim.api.nvim_del_autocmd(autocmd)
		end
	end

	function O.update()
		-- delete windows
		utils.win_remove(O.bufnr)

		local pwinid = utils.win_from_buf(O.pbufnr)
		if pwinid == nil then return end
		local dims = utils.win_get_size(O.pbufnr)
		assert(dims ~= nil, "Embterm: Unreachable control flow")

		-- buffer height and scroll calculation
		local height = O.selection.last - O.selection.start + 1
		local pview = utils.win_get_view(O.pbufnr)
		assert(pview ~= nil, "Embterm: Unreachable control flow")
		local ptopline = pview.topline
		local topline = ptopline - O.selection.start + 1
		if ptopline > O.selection.start then
			height = math.max(O.selection.last - ptopline + 1, 0)
		end
		if ptopline + dims.height - 1 < O.selection.last then
			height = math.max(ptopline + dims.height - O.selection.start, 0)
		end
		local lines = vim.api.nvim_buf_line_count(O.bufnr)
		print(topline, ptopline, O.selection.start, height)
		if topline > lines then
			topline = lines
		end
		if topline < 1 then
			topline = 1
		end
		pview.topline = topline

		-- create window if necessary
		if height == 0 then return end
		local win = vim.api.nvim_open_win(O.bufnr, false, {
			relative = 'win',
			win = pwinid,
			width = dims.width,
			height = height,
			col = 0,
			row = 0,
			bufpos = { O.selection.start - 1, O.selection.last - 1 },
			style = 'minimal',
			zindex = 45
		})
		utils.win_set_view(O.bufnr, pview)
	end

	-- autocmds
	O.autocmds[1] = vim.api.nvim_create_autocmd({ "TermClose", "QuitPre" }, {
		buffer = O.bufnr,
		callback = O.delete,
	})
	O.autocmds[2] = vim.api.nvim_create_autocmd({ "BufWinEnter", "WinScrolled", "BufWinLeave" }, {
		buffer = O.pbufnr,
		callback = O.update,
	})
	return O
end

return M
