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

return utils
