local win = require('embterm.window')
local obj


vim.api.nvim_create_user_command('EmbTermOpen', function()
	local path = debug.getinfo(1).source:sub(2, -9)
	obj = win.new({
		cmd1 = function(O)
		    -- Get the start and last marks of the current buffer
		    local start = vim.api.nvim_buf_get_mark(O.pbufnr, "<")
		    local last = vim.api.nvim_buf_get_mark(O.pbufnr, ">")

		    -- Construct the command to run the Python script
		    local command = "python3 "..path..'main.py .tmp.diff '..O.path..' '..start[1]..' '..last[1]

		    -- Schedule the print of the command after a short delay
		    vim.schedule(function() print(command) end)

		    -- Open the terminal and execute the command
		    vim.fn.termopen(command)

		    -- Resize the window to 3 lines
		    vim.cmd("resize 3")

		    -- Disable line numbers
		    vim.cmd("set nonumber")
		end,
		cmd2 = function(O)
			vim.cmd("diffthis")
			vim.schedule(function() vim.cmd("edit .tmp.diff") end)
			vim.cmd("set autoread")
			vim.api.nvim_create_autocmd({"CursorHold"}, {
				command = 'checktime | call feedkeys("lh")',
				pattern = "*"
			})
			vim.cmd('set updatetime=200')
		end,
		init = function(O)
			O.path = vim.fn.expand("%")
		end
	})
	-- vim.schedule(function() print(path) end)
end, {})
-- vim.api.nvim_create_user_command('EmbtermClose', function()
--	obj.delete()
-- end, {})
-- vim.api.nvim_create_user_command('EmbtermResume', function()
--	obj.resume()
-- end, {})
