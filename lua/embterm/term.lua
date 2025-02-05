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
	local bufwin = vim.fn.bufwinid(bufnr)

	-- Get the parent buffer number (i.e., the previous/next window)
	local pwin = vim.fn.bufwinid(parent.bufnr)

	-- If there is no current window, exit function
	if bufwin == -1 then
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

-- Enables the module's functionality.
-- @note This function is a convenience wrapper for _enable().
function M.enable()
	-- Call the private enable function to set up the module.
	_enable()

	-- Set the enabled flag to true to indicate that the module is active.
	M.enabled = true
end

-- Disables all windows containing the current buffer.
-- 
-- This function closes all windows that contain the current buffer,
-- effectively hiding it from view. It is typically used when a
-- user wants to temporarily hide a buffer without deleting it.
local function _disable()
	-- Find all windows that contain the current buffer
	local wins = vim.fn.win_findbuf(bufnr)

	-- Close each window, making it invisible
	for _, win in ipairs(wins) do
		vim.api.nvim_win_close(win, true)
	end
end

-- Disables the plugin by deleting the current buffer and resetting internal state.
-- @details Deletes the current buffer and resets the plugin's internal state.
function M.disable()
	-- Call the parent class's disable method to ensure proper cleanup.
	_disable()

	-- Check if a valid buffer exists before attempting to delete it.
	if vim.api.nvim_buf_is_valid(bufnr) then
		-- Delete the current buffer with force, ensuring it is properly cleaned up.
		vim.api.nvim_buf_delete(bufnr, { force = true })
	end

	-- Indicate that the terminal was not opened during this session.
	term_unopened = true

	-- Reset the selection to nil, indicating no active selection.
	selection = nil

	-- Set the plugin's enabled state to false, effectively disabling it.
	M.enabled = false
end

-- Sets focus to the parent window of the current buffer.
-- If no parent window exists, it does nothing.
local function set_focus()
	-- Get the ID of the parent window of the current buffer
	local win = vim.fn.bufwinid(parent.bufnr)

	-- If there is no parent window, exit early
	if win == -1 then
		return
	end

	-- Set focus to the parent window
	vim.api.nvim_set_current_win(win)
end

-- Create a new window with the specified configuration.
-- @param config A table containing the following keys:
--   - cmd: The command to open in the terminal.
--   - priv: The private key for the terminal.
function M.setup(config)
	-- Get the command and private key from the config table
	cmd = config.cmd
	mark = config.priv
	bufnr = vim.api.nvim_create_buf(false, true)

	-- Get the current window information
	local pwinnr = vim.fn.winnr()
	parent = vim.fn.getwininfo()[pwinnr]

	-- Enable the plugin
	M.enable()

	-- Check if a terminal is already open in the buffer
	if not vim.fn.bufwinid(bufnr) == -1 then
		-- Open a new terminal with the specified command and private key
		vim.fn.termopen(cmd)
		term_unopened = false
	end

	-- Schedule a function to set the current window to the parent window
	vim.schedule(function()
		vim.api.nvim_set_current_win(parent.winid)
	end)

	-- Create an autocmd group for the test window
	local autoclose = vim.api.nvim_create_augroup("TestWindow", {})

	-- Autocmds for when a buffer is entered or left
	vim.api.nvim_create_autocmd({ "BufWinEnter" }, {
		group = autoclose,
		buffer = parent.bufnr,
		callback = function()
			-- Schedule a function to toggle the enabled state and set focus
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
			-- Schedule a function to toggle the enabled state and set focus
			vim.schedule(function()
				if M.enabled then
					_disable()
					_enable()
					set_focus()
				end
			end)
		end,
	})

	-- Autocmds for when the terminal is closed or the buffer is deleted
	vim.api.nvim_create_autocmd({ "TermClose", "QuitPre", "BufDelete" }, {
		group = autoclose,
		buffer = bufnr,
		callback = function()
			-- Schedule a function to disable the plugin
			vim.schedule(function()
				M.disable()
			end)
		end,
	})

	-- Autocmd for when a buffer is entered
	vim.api.nvim_create_autocmd({ "BufEnter" }, {
		group = autoclose,
		buffer = bufnr,
		callback = function()
			-- Schedule a function to set focus if the current window matches the parent window
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

-- Creates a new Vim window with the specified buffer number.
-- @param bufnr number The buffer number to create the window for.
function M.create_vim_window(bufnr)
	-- Get the visual selection from the cursor.
	selection = cursor.visual(parent, mark)

	-- Check if there is a valid selection.
	local res = cursor.selection(parent, selection)
	if not res then
		return
	end

	-- Get the buffer window ID.
	local pwinid = vim.fn.bufwinid(parent.bufnr)
	if pwinid == -1 then
		-- If no buffer window is found, make the new buffer invisible.
		buf_invis = true
		return
	else
		-- Set the flag to indicate that the buffer is not invisible.
		buf_invis = false
	end

	if res == nil then
		return
	end
	-- Get the top and bottom positions of the selection.
	local top = res.top
	local bottom = res.bot

	-- Check if the selection spans an entire line.
	if top == bottom then
		-- If it does, make the buffer invisible.
		buf_invis = true
		return
	else
		-- Set the flag to indicate that the buffer is not invisible.
		buf_invis = false
	end

	-- Get the size of the buffer window.
	local size = get_buf_size(pwinid)

	-- Open a new Vim window with the specified settings.
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

	-- Open a new terminal if one is not already open.
	if term_unopened then
		vim.fn.termopen(cmd)
		term_unopened = false
	end
end

return M
