local utils = {}

-- Remove all buffers from a given window number.
-- @part:q!am bufnr number The window number to remove buffers from.
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
	-- source buffer info
	O.src = source
	-- destination buffer info
	O.dest = destination
	-- syncing text data
	O.text = {}
	O.fill = {}
	O.length = vim.api.nvim_buf_line_count(source)
	-- restore info
	local exts = {}
	local overwrite = vim.api.nvim_buf_get_lines(destination, start_row-1, end_row, false)
	local ns = vim.api.nvim_create_namespace("embterm")
	local autocmds = {}
	-- extmarks
	O.src_start_ext = vim.api.nvim_buf_set_extmark(O.src, ns, 0, 0, {})
	O.src_end_ext = vim.api.nvim_buf_set_extmark(O.src, ns, O.length-1, 0, {})
	O.dest_start_ext = vim.api.nvim_buf_set_extmark(O.dest, ns, start_row, 0, {})
	O.dest_end_ext = vim.api.nvim_buf_set_extmark(O.dest, ns, end_row, 0, {})

	local function print_ds(text)
		local dest_start = vim.api.nvim_buf_get_extmark_by_id(O.dest, ns, O.dest_start_ext, {})[1]
		print(text .. dest_start)
	end

	local function _update_exts()
		O.length = vim.api.nvim_buf_line_count(source)
		local src_last = vim.api.nvim_buf_get_extmark_by_id(O.src, ns, O.src_end_ext, {})[1]
		if src_last ~= O.length-1 then
			vim.api.nvim_buf_del_extmark(O.src, ns, O.src_end_ext)
			O.src_end_ext = vim.api.nvim_buf_set_extmark(O.src, ns, O.length-1, 0, {})
		end
		local dest_last = vim.api.nvim_buf_get_extmark_by_id(O.dest, ns, O.dest_end_ext, {})[1]
		if dest_last < start_row then
			vim.api.nvim_buf_del_extmark(O.dest, ns, O.dest_end_ext)
			O.dest_end_ext = vim.api.nvim_buf_set_extmark(O.dest, ns, start_row, 0, {})
		end
	end
	local function _update(bufnr, start_ext, end_ext, update_fills, offset)
		O.text = {}
		O.fill = {}
		local start = vim.api.nvim_buf_get_extmark_by_id(bufnr, ns, start_ext, {})[1]
		local last = vim.api.nvim_buf_get_extmark_by_id(bufnr, ns, end_ext, {})[1]
		-- get length
		O.length = last - start + 1
		-- get text
		O.text = vim.api.nvim_buf_get_lines(bufnr, start - 1 + offset, last + offset, false)
		-- get fills
		if not update_fills then return end
		local winid = utils.win_from_buf(bufnr)
		if winid == nil then return nil end
		for i = 0, O.length-1 do
			local fill = vim.api.nvim_win_text_height(winid, {
				start_row = i + start,
				end_row = i + start,
			}).fill
			O.fill[i+1] = fill
		end
	end
	local function _copy(bufnr, start_ext, end_ext, update_fills, offset)
		local start = vim.api.nvim_buf_get_extmark_by_id(bufnr, ns, start_ext, {})[1]
		local last = vim.api.nvim_buf_get_extmark_by_id(bufnr, ns, end_ext, {})[1]
		vim.api.nvim_buf_set_lines(bufnr, start - 1 + offset, last + offset, false, O.text)
		if not update_fills then return end
		for i = 0, O.length-1 do
			local vt = {}
			for j = 1, O.fill[i+1] do
				vt[j] = {{""}}
			end
			exts[i+1] = vim.api.nvim_buf_set_extmark(bufnr, ns, start + i, 0, {
				virt_lines = vt
			})
		end
	end

	function O.update_from_source()
		vim.api.nvim_buf_del_extmark(O.src, ns, O.src_start_ext)
		vim.api.nvim_buf_del_extmark(O.dest, ns, O.dest_start_ext)
		O.src_start_ext = vim.api.nvim_buf_set_extmark(O.src, ns, 0, 0, {})
		O.dest_start_ext = vim.api.nvim_buf_set_extmark(O.dest, ns, start_row, 0, {})
		_update_exts()
		_update(O.src, O.src_start_ext, O.src_end_ext, true, 1)
	end
	function O.update_from_dest()
		vim.api.nvim_buf_del_extmark(O.src, ns, O.src_start_ext)
		vim.api.nvim_buf_del_extmark(O.dest, ns, O.dest_start_ext)
		O.src_start_ext = vim.api.nvim_buf_set_extmark(O.src, ns, 0, 0, {})
		O.dest_start_ext = vim.api.nvim_buf_set_extmark(O.dest, ns, start_row, 0, {})
		_update(O.dest, O.dest_start_ext, O.dest_end_ext, false, 0)
		_update_exts()
	end

	function O.copy_to_dest()
		_copy(O.dest, O.dest_start_ext, O.dest_end_ext, true, 0)
	end
	function O.copy_to_source()
		_copy(O.src, O.src_start_ext, O.src_end_ext, false, 1)
	end

	function O.restore()
		local start = vim.api.nvim_buf_get_extmark_by_id(O.dest, ns, O.dest_start_ext, {})[1]
		local last = vim.api.nvim_buf_get_extmark_by_id(O.dest, ns, O.dest_end_ext, {})[1]
		vim.api.nvim_buf_set_lines(O.dest, start-1, last, false, overwrite)
		for _, ext in ipairs(exts) do
			vim.api.nvim_buf_del_extmark(O.dest, ns, ext)
		end
	end

	function O.delete()
		local start = start_row
		local last = vim.api.nvim_buf_get_extmark_by_id(O.dest, ns, O.dest_end_ext, {})[1]
		vim.schedule(function() vim.api.nvim_buf_set_lines(O.dest, start-1, last, false, overwrite) end)
		for _, ext in ipairs(exts) do
			vim.api.nvim_buf_del_extmark(O.dest, ns, ext)
		end
		if vim.api.nvim_buf_is_valid(O.src) then
			vim.api.nvim_buf_del_extmark(O.src, ns, O.src_start_ext)
			vim.api.nvim_buf_del_extmark(O.src, ns, O.src_end_ext)
			vim.api.nvim_buf_del_extmark(O.dest, ns, O.dest_start_ext)
			vim.api.nvim_buf_del_extmark(O.dest, ns, O.dest_end_ext)
			vim.api.nvim_del_autocmd(autocmds[1])
			vim.api.nvim_del_autocmd(autocmds[3])
		end
		vim.api.nvim_del_autocmd(autocmds[2])
	end

	O.restore()
	O.update_from_source()
	O.copy_to_dest()

	autocmds[1] = vim.api.nvim_create_autocmd({ "TextChanged", "TextChangedI" }, {
		buffer = O.src,
		callback = function()
			O.restore()
			O.update_from_source()
			O.copy_to_dest()
		end
	})
	autocmds[2] = vim.api.nvim_create_autocmd({ "TextChanged", "TextChangedI" }, {
		buffer = O.dest,
		callback = function()
			if vim.api.nvim_buf_is_valid(O.src) then
				O.update_from_dest()
				O.copy_to_source()
			else
				vim.schedule(O.delete)
			end
		end
	})
	autocmds[3] = vim.api.nvim_create_autocmd({ "BufDelete" }, {
		buffer = O.src,
		callback = function()
			O.restore()
			vim.schedule(O.delete)
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
