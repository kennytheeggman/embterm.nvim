local M = {}


function M.new(config)
	local cmd1 = config.cmd1
	local cmd2 = config.cmd2
	local init = config.init
	local O = {}
	local id = vim.api.nvim_create_augroup("embterm", {})
	init(O)
	local cmds = {}

	-- parent and child buffers
	O.pbufnr = vim.api.nvim_get_current_buf()
	O.bufnr1 = vim.api.nvim_create_buf(true, true)
	O.bufnr2 = vim.api.nvim_create_buf(true, true)

	-- resume split window
	function O.resume()
		-- TODO: check here if buffers are valid
		vim.cmd("diffthis")
		if O.winid1 == nil then
			vim.cmd("botright vnew")
			O.winid1 = vim.api.nvim_get_current_win()
			vim.api.nvim_win_set_buf(O.winid1, O.bufnr1)
		end
		if O.winid2 == nil then
			vim.cmd("new")
			O.winid2 = vim.api.nvim_get_current_win()
			vim.api.nvim_win_set_buf(O.winid2, O.bufnr2)
		end
		vim.api.nvim_win_call(O.winid2, function() cmd2(O) end)
		vim.api.nvim_win_call(O.winid1, function() cmd1(O) end)
	end

	-- update winid to ensure validity
	function O.update()
		if O.winid1 and not vim.api.nvim_win_is_valid(O.winid1) then
			O.winid1 = nil
		end
		if O.winid2 and not vim.api.nvim_win_is_valid(O.winid2) then
			O.winid2 = nil
		end
		local winid = vim.fn.bufwinid(O.pbufnr)
		if winid == -1 then
			if O.winid1 then
				vim.api.nvim_win_close(O.winid1, false)
			end
			if O.winid2 then
				vim.api.nvim_win_close(O.winid2, false)
			end
		else if not O.winid1 or not O.winid2 then
			O.resume()
		end end
	end

	-- delete windows
	function O.delete()
		if O.winid1 then
			vim.api.nvim_win_close(O.winid1, false)
		end
		if O.winid2 then
			vim.api.nvim_win_close(O.winid2, false)
		end
		O.winid1 = nil
		O.winid2 = nil
		for i = 1,1 do
			vim.api.nvim_del_autocmd(cmds[i])
		end
		vim.api.nvim_buf_delete(O.bufnr1, {force=true})
		vim.api.nvim_buf_delete(O.bufnr2, {force=true})
	end

	-- initialization code
	O.resume()
	cmds[1] = vim.api.nvim_create_autocmd({"BufWinEnter"}, {
		group = id,
		callback = O.update
	})
	cmds[2] = vim.api.nvim_create_autocmd({"WinClosed", "TermClose"}, {
		group = id,
		callback = function()
			O.delete()
		end,
		buffer = O.bufnr1
	})
	cmds[3] = vim.api.nvim_create_autocmd({"WinClosed", "TermClose"}, {
		group = id,
		callback = function()
			O.delete()
		end,
		buffer = O.bufnr2
	})
	return O
end

return M
