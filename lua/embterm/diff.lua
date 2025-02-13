local utils = require('lua.embterm.utils')

local function get_update_height(O, min_height)
	-- get heights of buffers
	local height1 = vim.api.nvim_buf_line_count(O.bufnr1)
	local winid1 = utils.win_from_buf(O.bufnr1)
	if winid1 ~= nil then
		height1 = vim.api.nvim_win_text_height(winid1, {
			start_row = 0,
			end_row = -1
		})
	end
	local height2 = vim.api.nvim_buf_line_count(O.bufnr2)
	local winid2 = utils.win_from_buf(O.bufnr1)
	if winid1 ~= nil then
		height1 = vim.api.nvim_win_text_height(winid2, {
			start_row = 0,
			end_row = -1
		})
	end

	-- begin height calculation
	local height_want = math.max(height1, height2, min_height)
	local height = height_want
	local start_row = O.selection.start

	-- parent view info
	local _pview = utils.win_get_view(O.pbufnr)
	assert(_pview ~= nil, "Embterm: Unreachable control flow")
	local _pdims = utils.win_get_size(O.pbufnr)
	assert(_pdims ~= nil, "Embterm: Unreachable control flow")
	local pwinid = utils.win_from_buf(O.pbufnr)
	assert(pwinid ~= nil, "Embterm: Unreachable control flow")

	local pheight = _pdims.height
	local ptopline = _pview.topline
	local ptopfill = _pview.topfill

	-- if the buffer intersects with the top of the screen
	if ptopline > start_row then
		local start_to_topline = vim.api.nvim_win_text_height(pwinid, {
			start_row = start_row,
			end_row = ptopline
		}).all - ptopfill
		height = math.min(pheight, math.max(0, height_want - start_to_topline + 1))
	else
		local buf_to_topline = vim.api.nvim_win_text_height(pwinid, {
			start_row = 0,
			end_row = ptopline
		}).all - ptopfill
		local buf_to_start = vim.api.nvim_win_text_height(pwinid, {
			start_row = 0,
			end_row = start_row-1,
		}).all
		local start_pos = buf_to_start - buf_to_topline
		height = math.max(0, math.min(pheight - start_pos - 1, height_want))
	end
	return height
end
local function get_update_view(O, bufnr)
	local start_row = O.selection.start
	local height = vim.api.nvim_buf_line_count(bufnr)
	local winid = utils.win_from_buf(bufnr)
	if winid == nil then return nil end

	-- parent view info
	local _pview = utils.win_get_view(O.pbufnr)
	assert(_pview ~= nil, "Embterm: Unreachable control flow")
	local pwinid = utils.win_from_buf(O.pbufnr)
	assert(pwinid ~= nil, "Embterm: Unreachable control flow")

	local ptopline = _pview.topline
	local ptopfill = _pview.topfill

	-- if the buffer intersects with the top of the screen
	if ptopline > start_row then
		-- how far down should the topline be in screen units
		local start_to_topline = vim.api.nvim_win_text_height(pwinid, {
			start_row = start_row,
			end_row = ptopline
		}).all - ptopfill
		local topline = height
		local topfill = 0
		-- linear search for how far it is
		for i = 0, height-1 do
			local to_i = vim.api.nvim_win_text_height(winid, {
				start_row = 0,
				end_row = i
			}).all
			if to_i >= start_to_topline then
				topline = i + 1
				topfill = to_i - start_to_topline
				break
			end
		end
		-- return view
		return { topline = topline, topfill = topfill, lnum = topline }
	end
	return { topline = 1, topfill = 0, lnum = 1 }
end

local diff = {}

function diff.new(parent, config)
	local O = {}
	O.pbufnr = parent
	O.cmd = config.cmd
	O.selection = config.range
	-- asserts
	assert(O.pbufnr ~= nil, "Embterm: parent should not be nil")
	assert(O.cmd ~= nil, "Embterm: config.cmd should not be nil")
	assert(O.selection ~= nil, "Embterm: config.range should not be nil")

	O.bufnr1 = vim.api.nvim_create_buf(false, true)
	O.bufnr2 = vim.api.nvim_create_buf(false, true)
	O.autocmds = {}

	function O.delete()
		-- delete windows
		utils.win_remove(O.bufnr1)
		utils.win_remove(O.bufnr2)
		-- delete buffer
		if vim.api.nvim_buf_is_valid(O.bufnr1) then
			vim.api.nvim_buf_delete(O.bufnr1, { force = true })
		end
		if vim.api.nvim_buf_is_valid(O.bufnr2) then
			vim.api.nvim_buf_delete(O.bufnr2, { force = true })
		end
		-- delete autocmds
		for _, autocmd in ipairs(O.autocmds) do
			vim.api.nvim_del_autocmd(autocmd)
		end
	end

	function O.update()
		-- delete windows
		utils.win_remove(O.bufnr1)
		utils.win_remove(O.bufnr2)

		local pwinid = utils.win_from_buf(O.pbufnr)
		if pwinid == nil then return end
		local dims = utils.win_get_size(O.pbufnr)
		assert(dims ~= nil, "Embterm: Unreachable control flow")

		-- buffer height and scroll calculation
		local height = get_update_height(O, O.selection.last - O.selection.start + 1)
		if height == 0 then return end

		-- create window if necessary
		local win1 = vim.api.nvim_open_win(O.bufnr1, false, {
			relative = 'win',
			win = pwinid,
			width = math.floor(dims.width/2) + 2,
			height = height,
			col = -3,
			row = 0,
			bufpos = { O.selection.start - 1, -2 },
			style = 'minimal',
			zindex = 45
		})
		local win2 = vim.api.nvim_open_win(O.bufnr2, false, {
			relative = 'win',
			win = pwinid,
			width = dims.width - math.floor(dims.width/2) + 1,
			height = height,
			col = math.floor(dims.width/2) + 2,
			row = 0,
			bufpos = { O.selection.start - 1, math.floor(dims.width/2) + 2 },
			style = 'minimal',
			zindex = 45
		})

		O.cmd(win1, win2)

		local view1 = get_update_view(O, O.bufnr1)
		local view2 = get_update_view(O, O.bufnr2)
		assert(view1 ~= nil, "Embterm: Unreachable control flow")
		assert(view2 ~= nil, "Embterm: Unreachable control flow")
		utils.win_set_view(O.bufnr1, view1)
		utils.win_set_view(O.bufnr2, view2)
	end

	-- autocmds
	O.autocmds[1] = vim.api.nvim_create_autocmd({ "TermClose", "QuitPre" }, {
		buffer = O.bufnr1,
		callback = O.delete,
	})
	O.autocmds[1] = vim.api.nvim_create_autocmd({ "TermClose", "QuitPre" }, {
		buffer = O.bufnr2,
		callback = O.delete,
	})
	O.autocmds[2] = vim.api.nvim_create_autocmd({ "BufWinEnter", "WinScrolled", "BufWinLeave" }, {
		buffer = O.pbufnr,
		callback = O.update,
	})
	return O
end

return diff
