M = {}

-- Calculates the adjusted marks for a visual selection in a Vim window.
-- @param parent The parent object containing the buffer and window information.
-- @return A table with the adjusted start and last marks of the visual selection,
--         or nil if no valid marks are found.
function M.visual(parent, mark)
	-- Get the initial marks from the buffer
	local start = vim.api.nvim_buf_get_mark(parent.bufnr, mark.start)[1]
	local last = vim.api.nvim_buf_get_mark(parent.bufnr, mark.last)[1]

	local winid = vim.fn.bufwinid(parent.bufnr)
	if winid == -1 then
		return nil
	end
	-- Get the window information and convert the winid to a window number
	local info = vim.fn.getwininfo()[vim.fn.win_id2win(winid)]

	-- Check if both start and last marks are valid
	if last == 0 or start == 0 then
		return { start = 0, last = 0 }
	end

	-- Calculate the adjusted marks based on the window's scroll position
	local scroll = info.topline
	return { start = start - scroll, last = last - scroll, raw = { start = start, last = last } }
end

-- Returns the number of lines from the top of the window to the current cursor position.
-- 
-- @param parent The parent window object.
-- @return The number of lines from the top of the window to the current cursor position.
function M.normal(parent)
	local winid = vim.fn.bufwinid(parent.bufnr)
	if winid == -1 then
		return nil
	end
	-- Get the current cursor position in the window.
	local cursor = vim.api.nvim_win_get_cursor(winid)

	-- Retrieve information about the window, including its scroll position.
	local info = vim.fn.getwininfo(winid)[1]

	-- Get the top line of the window.
	local scroll = info.topline

	-- Calculate the number of lines from the top of the window to the current cursor position.
	return cursor[1]
end


-- Returns the range of lines in a visual selection.
-- 
-- @param parent The parent window to retrieve the selection from.
-- @return A table containing two values: the first line number and the last line number in the selection.
function M.selection(parent, selection)
	-- Get the cursor position for the given window
	local cursor = selection
	local winid = vim.fn.bufwinid(parent.bufnr)
	if winid == -1 then
		return nil
	end
	if cursor == nil then
		return nil
	end
	local height = vim.api.nvim_win_get_height(winid)
	-- local real_height = math.max(0, cursor.last) - math.max(0, cursor.start)
	-- cursor.last = cursor.start + real_height

	-- Calculate the top line number in the selection
	-- Clamp to 0 if below the first line, otherwise clamp to the height minus one
	local top = math.min(height, math.max(0, cursor.start))

	-- Calculate the bottom line number in the selection
	-- Clamp to 1 if above the last line, otherwise clamp to the height
	local bottom = math.min(height, math.max(0, cursor.last))

	return { top=top, bot=bottom }
end


return M
