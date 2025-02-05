local M = {}


local cursor = require("embterm.cursor")
local bufnr
local parent
local buf_invis
local term_unopened = true
local selection
local prefoc

local cmd
local mark

M.enabled = true

-- Focuses on the selected text in a buffer.
-- @param dont_pre Optional boolean to prevent subsequent focus calls.
function M.focus(dont_pre)
	-- Get the current buffer and parent buffer IDs
	local bufwin = vim.fn.bufwinid(bufnr)
	local pwin = vim.fn.bufwinid(parent.bufnr)

	-- Check if there is a selection
	if selection == nil then
		return
	end

	-- If no parent buffer, focus on the current buffer
	if pwin == -1 then
		return
	end

	-- If dont_pre is not set, get the cursor position in the parent buffer
	if dont_pre == nil then
		prefoc = vim.api.nvim_win_get_cursor(pwin)
	elseif bufwin == -1 then
		return
	end

	-- If no current buffer, schedule a focus call for later
	if bufwin == -1 then
		vim.api.nvim_win_set_cursor(pwin, { selection.raw.start, 0 })
		vim.schedule(function()
			M.focus(true)
		end)
		return
	end

	-- Set the current window to the selected buffer
	vim.api.nvim_set_current_win(bufwin)
end

-- Set the current window to be focused and its cursor position
function M.defocus()
	-- Get the buffer number of the current window
	local bufnr = vim.fn.bufnr("%")

	-- Get the parent buffer number (i.e., the previous/next window)
	local pwin = vim.fn.bufwinid(parent.bufnr)

	-- If there is no current window, exit function
	if bufnr == -1 then
		return
	end

	-- Set the current window to be focused
	vim.api.nvim_set_current_win(pwin)

	-- Set the cursor position in the current window (assuming prefoc is a valid value)
	vim.api.nvim_win_set_cursor(pwin, prefoc)
end

-- /// Returns the size of a Vim window as a table with width and height.
local function get_buf_size(winid)
	-- Get the width of the window by calling vim.api.nvim_win_get_width.
	local width = vim.api.nvim_win_get_width(winid)

	-- Get the height of the window by calling vim.api.nvim_win_get_height.
	local height = vim.api.nvim_win_get_height(winid)

	-- Return a table with the width and height as its values.
	return { width = width, height = height }
end

-- Enable Vim window functionality.
-- Creates a new Vim window for the specified buffer number.
-- If no window is created, it will disable itself if it's invisible.
local function _enable()
	-- Create a new Vim window for the given buffer number.
	M.create_vim_window(bufnr)

	-- Get the ID of the newly created window.
	local wins = vim.fn.bufwinid(bufnr)

	-- If no window was created, disable the plugin if it's invisible.
	if wins == -1 and not buf_invis then
		M.disable()
	end
end

--/// document the following function with docstring and comments
function M.enable()
	_enable()
	M.enabled = true
end
--/// document the following function with docstring and comments
local function _disable()
	local wins = vim.fn.win_findbuf(bufnr)
	for _, win in ipairs(wins) do
		vim.api.nvim_win_close(win, true)
	end
end
--/// document the following function with docstring and comments
function M.disable()
	_disable()
	if vim.api.nvim_buf_is_valid(bufnr) then
		vim.api.nvim_buf_delete(bufnr, { force = true })
	end
	term_unopened = true
	selection = nil
	M.enabled = false
end

--/// document the following function with docstring and comments
local function set_focus()
	local win = vim.fn.bufwinid(parent.bufnr)
	if win == -1 then
		return
	end
	vim.api.nvim_set_current_win(win)
end

--/// document the following function with docstring and comments
function M.setup(config)
	cmd = config.cmd
	mark = config.priv
	bufnr = vim.api.nvim_create_buf(false, true)
	local pwinnr = vim.fn.winnr()
	parent = vim.fn.getwininfo()[pwinnr]
	-- vim.api.nvim_open_term(bufnr, {})
	M.enable()
	if not vim.fn.bufwinid(bufnr) == -1 then
		vim.fn.termopen(cmd)
		term_unopened = false
	end
	vim.schedule(function()
		vim.api.nvim_set_current_win(parent.winid)
	end)
	local autoclose = vim.api.nvim_create_augroup("TestWindow", {})
	vim.api.nvim_create_autocmd({ "BufWinEnter" }, {
		group = autoclose,
		buffer = parent.bufnr,
		callback = function()
			vim.schedule(function()
				if M.enabled then
					_disable()
					_enable()
					set_focus()
				end
			end)
		end,
	})
	vim.api.nvim_create_autocmd({ "WinScrolled", "BufWinLeave" }, {
		group = autoclose,
		buffer = parent.bufnr,
		callback = function()
			vim.schedule(function()
				if M.enabled then
					_disable()
					_enable()
					set_focus()
				end
			end)
		end,
	})
	vim.api.nvim_create_autocmd({ "TermClose", "QuitPre", "BufDelete" }, {
		group = autoclose,
		buffer = bufnr,
		callback = function()
			vim.schedule(function()
				M.disable()
			end)
		end,
	})
	vim.api.nvim_create_autocmd({ "BufEnter" }, {
		group = autoclose,
		buffer = bufnr,
		callback = function()
			vim.schedule(function()
				local cur = vim.fn.winnr()
				local winid = vim.fn.win_getid(cur)
				local wins = vim.fn.bufwinid(bufnr)
				if winid == wins then
					vim.cmd("startinsert")
				end
			end)
		end,
	})
end

--/// document the following function with docstring and comments
function M.create_vim_window(bufnr)
	-- Create a new Vim window
	selection = cursor.visual(parent, mark)
	local res = cursor.selection(parent, selection)
	local pwinid = vim.fn.bufwinid(parent.bufnr)
	if pwinid == -1 then
		buf_invis = true
		return
	else
		buf_invis = false
	end
	if res == nil then
		return
	end
	local top = res.top
	local bottom = res.bot
	if top == bottom then
		buf_invis = true
		return
	else
		buf_invis = false
	end
	local size = get_buf_size(pwinid)
	local win = vim.api.nvim_open_win(bufnr, true, {
		relative = 'win',
		win = pwinid,
		width = size.width,
		height = bottom-top+1,
		col = 0,
		row = top,
		style = 'minimal',
		focusable = false,
		zindex = 45
	})
	if term_unopened then
		vim.fn.termopen(cmd)
		term_unopened = false
	end
end




return M

