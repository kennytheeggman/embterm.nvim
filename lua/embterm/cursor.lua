M = {}

local function rowtoscreen(winid, row, front)
	-- row 1 to row row
	local torow = vim.api.nvim_win_text_height(winid, {
		start_row = 1,
		end_row = row
	}).all
	if front then
		local inclusive_row = vim.api.nvim_win_text_height(winid, {
			start_row = row,
			end_row = row,
		}).fill
		local temp = torow - inclusive_row
		torow = temp
	end
	-- row 1 to screen top
	local view = vim.api.nvim_win_call(winid, vim.fn.winsaveview)
	if view.topfill == 0 then
		local inclusive_topfill = vim.api.nvim_win_text_height(winid, {
			start_row = view.topline,
			end_row = view.topline,
		}).fill
		view.topfill = inclusive_topfill
	end
	local totop = vim.api.nvim_win_text_height(winid, {
		start_row = 1,
		end_row = view.topline
	}).all
	local top = totop - view.topfill
	return torow - top
end

function M.relative(bufnr, selection, offsets)
	local winid = vim.fn.bufwinid(bufnr)
	if winid == -1 then
		return nil
	end
	if offsets == nil then
		offsets = { start = 0, last = 0 }
	end
	local start = rowtoscreen(winid, selection.start, true)
	local last = rowtoscreen(winid, selection.last, false)
	return { start = start + offsets.start, last = last + offsets.last }
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
	local top = math.min(height-1, math.max(0, selection.start))
	local bottom = math.min(height-1, math.max(0, selection.last))
	return { start = top, last = bottom }
end

function M.normal(bufnr)
	local winid = vim.fn.bufwinid(bufnr)
	if winid == -1 then
		return nil
	end
	local cursor = vim.api.nvim_win_get_cursor(winid)[1]
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
