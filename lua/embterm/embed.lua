local utils = {}

-- Remove all buffers from a given window number.
-- @param bufnr number The window number to remove buffers from.
-- @return none
function utils.win_remove(bufnr)
	-- Find the buffer numbers in the specified window.
	local winids = vim.fn.win_findbuf(bufnr)
	-- Close each window with its associated buffer, removing it from memory.
	for _, winid in ipairs(winids) do
		vim.api.nvim_win_close(winid, true)
	end
end

-- Returns the window ID associated with the given buffer number.
-- @param bufnr number The buffer number to find the corresponding window for.
-- @return number|nil The window ID if found, or nil otherwise.
function utils.win_from_buf(bufnr)
	local winid = vim.fn.bufwinid(bufnr)
	if winid == -1 then return nil end
	return winid
end

-- @brief Returns the size of a Vim window.
-- @param bufnr The buffer number of the window to retrieve size for.
-- @return A table containing the width and height of the window, or nil if no window is found.
function utils.win_get_size(bufnr)
	-- Get the ID of the corresponding window
	local winid = utils.win_from_buf(bufnr)
	-- If no window is found, return nil
	if winid == nil then return nil end
	-- Get the width and height of the window
	local width = vim.api.nvim_win_get_width(winid)
	local height = vim.api.nvim_win_get_height(winid)
	-- Return the size as a table
	return { width = width, height = height }
end

-- Returns the saved view of a window for the given buffer number.
-- @param bufnr number The buffer number to retrieve the view for.
-- @return table|nil The saved view or nil if no view exists.
function utils.win_get_view(bufnr)
    local winid = utils.win_from_buf(bufnr)
    if winid == nil then return nil end
    local view = vim.api.nvim_win_call(winid, vim.fn.winsaveview)
    return view
end





local text = {}

function text.new(source, destination, start_row, end_row)
	local O = {}
	O.bufnr = source
	O.dest = destination
	O.overwrite = {}
	O.overwrite_start = 0
	O.overwrite_end = 0
	O.text = {}
	O.fill = {}
	O.exts = {}
	O.length = 0
	local ns = vim.api.nvim_create_namespace("embterm")

	local function _update(bufnr, get_length)
		O.text = {}
		O.fill = {}
		if get_length then
			O.length = vim.api.nvim_buf_line_count(bufnr)
		end
		if O.length == nil then return nil end

		local winid = utils.win_from_buf(bufnr)
		if winid == nil then return nil end

		if get_length then
			O.text = vim.api.nvim_buf_get_lines(bufnr, 0, -1, false)
		else
			O.text = vim.api.nvim_buf_get_lines(bufnr, O.overwrite_start, O.overwrite_end, false)
		end

		for i = 0, O.length-1 do
			local fill = vim.api.nvim_win_text_height(winid, {
				start_row = i,
				end_row = i,
			}).fill
			O.fill[i+1] = fill
		end

	end

	function O.update_from_source()
		_update(O.bufnr, true)
	end
	function O.update_from_dest()
		_update(O.dest, false)
	end

	function O.copy(get_length)
		O.overwrite = vim.api.nvim_buf_get_lines(O.dest, start_row, end_row, false)
		vim.api.nvim_buf_set_lines(O.dest, start_row, end_row, false, O.text)
		O.overwrite_start = start_row
		O.overwrite_end = start_row + O.length
		for i = 0, O.length-1 do
			local vt = {}
			for j = 1, O.fill[i+1] do
				vt[j] = {{""}}
			end
			O.exts[i+1] = vim.api.nvim_buf_set_extmark(O.dest, ns, start_row + i, 0, {
				virt_lines = vt
			})
		end
	end

	function O.restore()
		vim.api.nvim_buf_set_lines(O.dest, O.overwrite_start, O.overwrite_end, false, O.overwrite)
		for _, ext in ipairs(O.exts) do
			vim.api.nvim_buf_del_extmark(O.dest, ns, ext)
		end
	end

	O.update_from_source()

	vim.api.nvim_create_autocmd({ "TextChanged", "TextChangedI" }, {
		buffer = O.bufnr,
		callback = function()
			O.update_from_source()
			O.restore()
			O.copy()
		end
	})
	vim.api.nvim_create_autocmd({ "TextChanged", "TextChangedI" }, {
		buffer = O.dest,
		callback = function()
			O.update_from_dest()
			O.restore()
			O.copy()
		end
	})

	return O
end


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

		-- buffer height calculation
		local height = O.selection.last - O.selection.start + 1
		local ptopline = utils.win_get_view(O.pbufnr).topline
		assert(ptopline ~= nil, "Embterm: Unreachable control flow")
		if ptopline > O.selection.start then
			height = math.max(O.selection.last - ptopline + 1, 0)
		end
		if ptopline + dims.height - 1 < O.selection.last then
			height = math.max(ptopline + dims.height - O.selection.start, 0)
		end

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
