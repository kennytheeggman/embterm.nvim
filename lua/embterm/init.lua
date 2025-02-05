local M = {}

local term = require("embterm.term")

local config

function M.quick_setup()
	-- Set up the configuration for the quick setup function
	M.setup({
		-- Command to use for the setup
		cmd = "bash",

		-- Keybinds for the setup
		keybinds = {
			{ "n", "<C-i>f", "<cmd>EmbTermFocus<cr>" },  -- Focus on a terminal
			{ "t", "<C-i>f", "<cmd>EmbTermDefocus<cr>" },  -- Defocus from a terminal
			{ "n", "<C-i>i", "<cmd>EmbTermOpen<cr>" },     -- Open a new terminal
		},

		-- Markers for the setup
		mark = {
			start = "<",  -- Start marker
			last = ">"   -- Last marker
		},

		-- Private mappings for the setup
		priv = {
			start = "8",  -- Start private mapping
			last = "9"    -- Last private mapping
		}
	})
end

-- Configuration management function.
-- @param prop string The property to be configured.
-- @param val any The value to be assigned to the specified property.
function M.config(prop, val)
	-- Update its value.
	config[prop] = val
end

-- /// Configure the terminal settings and bind keybindings.
function M.setup(conf)
	-- Store the configuration for later use.
	config = conf

	-- Initialize the terminal setup with the provided configuration.
	term.setup(config)

	-- Disable the terminal to prevent accidental opening.
	term.disable()

	-- Create user commands for common terminal operations.
	vim.api.nvim_create_user_command("EmbTermOpen", M.term, {})
	vim.api.nvim_create_user_command("EmbTermFocus", M.focus, {})
	vim.api.nvim_create_user_command("EmbTermDefocus", M.defocus, {})
	vim.api.nvim_create_user_command("EmbTermClose", M.close, {})
	local keybinds = conf.keybinds

	-- Bind keybindings to the terminal operations.
	local keybinds = config.keybinds
	for _, v in ipairs(keybinds) do
		-- Use noremap to prevent remapping of existing keys.
		vim.api.nvim_set_keymap(v[1], v[2], v[3], { noremap = true })
	end
end

-- Sets up and enables the terminal feature.
-- 
-- This function is responsible for setting up and enabling the terminal feature in Neovim.
-- It retrieves the current buffer, gets the start and last marks, sets new marks,
-- and if the terminal feature is not enabled, it sets up and enables it.
function M.term()
	-- Get the current buffer number
	local bufnr = vim.fn.getwininfo()[vim.fn.winnr()].bufnr

	-- Get the start and last marks of the current buffer
	local start = vim.api.nvim_buf_get_mark(bufnr, config.mark.start)
	local last = vim.api.nvim_buf_get_mark(bufnr, config.mark.last)

	-- Set new marks for the start and last positions
	vim.api.nvim_buf_set_mark(bufnr, config.priv.start, start[1], start[2], {})
	vim.api.nvim_buf_set_mark(bufnr, config.priv.last, last[1], last[2], {})

	-- If the terminal feature is not enabled, set it up and enable it
	if not term.enabled then
		-- Set up the terminal configuration
		term.setup(config)

		-- Enable the terminal feature
		term.enable()
	end
end

-- Close the terminal window, disabling any input or output.
function M.close()
	-- Disable the terminal to prevent any input or output.
	term.disable()
end

-- Focus the terminal window for keyboard and mouse events.
function M.focus()
	-- Bring the terminal to the front of the window stack.
	term.focus()
end

-- Defocus the terminal window, restoring any previous focus state.
function M.defocus()
	-- Restore the terminal's original focus state.
	term.defocus()
end

return M
