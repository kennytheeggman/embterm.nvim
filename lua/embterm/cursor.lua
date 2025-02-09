M = {}

function M.relative(bufnr, selection, post_selection_offset)
	local winid = vim.fn.bufwinid(bufnr)
	if winid == -1 then
		return nil
	end
	-- Get the window information and convert the winid to a window number
	local view = vim.api.nvim_win_call(winid, vim.fn.winsaveview)
	local topfill = view.topfill
	local topline = view.topline - 1
	local fillend = topline
	if topline <= selection.start then
		fillend = selection.start
	end
	local realfill = vim.api.nvim_win_text_height(winid, { start_row = topline, end_row = fillend }).fill	
	local post_offset = 0
	if topline > selection.last and topfill == 0 then
		post_offset = post_selection_offset
	else
	end
	local sfill = vim.api.nvim_win_text_height(winid, { start_row = topline, end_row = topline } ).fill
	local offset = topfill - realfill
	if topline < selection.start then
		if sfill ~= 0 then
			offset = topfill - realfill + post_selection_offset
		else
			offset = realfill - topfill
		end
	end
	local scroll = view.topline - offset + post_offset
	return { start = selection.start - scroll, last = selection.last - scroll }
end

function M.clamp(bufnr, selection)
	local winid = vim.fn.bufwinid(bufnr)
	if winid == -1 then
		return nil
	end
	if selection == nil then
		return nil
	end
	local height = vim.api.nvim_win_get_height(winid)
	local top = math.min(height, math.max(0, selection.start))
	local bottom = math.min(height, math.max(0, selection.last))
	return { start = top, last = bottom }
end

function M.normal(bufnr)
	local winid = vim.fn.bufwinid(bufnr)
	if winid == -1 then
		return nil
	end
	local cursor = vim.api.nvim_win_get_cursor(winid)
	return { start = cursor, last = cursor }
end

-- Calculates the adjusted marks for a visual selection in a Vim window.
-- @param parent The parent object containing the buffer and window information.
-- @return A table with the adjusted start and last marks of the visual selection,
--         or nil if no valid marks are found.
function M.visual(bufnr, mark)
	-- Get the initial marks from the buffer
	local start = vim.api.nvim_buf_get_mark(bufnr, mark.start)[1]
	local last = vim.api.nvim_buf_get_mark(bufnr, mark.last)[1]
	return { start = start, last = last }
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
	local top = math.min(height-1, math.max(0, cursor.start))

	-- Calculate the bottom line number in the selection
	-- Clamp to 1 if above the last line, otherwise clamp to the height
	local bottom = math.min(height-1, math.max(0, cursor.last))

	return { top=top, bot=bottom }
end


return M
