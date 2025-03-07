local M = {}


function M.new()
	local O = {}
	local id = vim.api.nvim_create_augroup("embterm", {})
	local cmds = {}

	-- parent and child buffers
	O.pbufnr = vim.api.nvim_get_current_buf()
	O.bufnr1 = vim.api.nvim_create_buf(true, true)
	O.bufnr2 = vim.api.nvim_create_buf(true, true)

	-- resume split window
	function O.resume()
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
		vim.api.nvim_win_call(O.winid2, function() vim.cmd("diffthis") end)
		vim.api.nvim_win_call(O.winid1, function() vim.fn.termopen("zsh") end)
		vim.api.nvim_win_call(O.winid1, function() vim.cmd("resize 10") end)
		vim.api.nvim_win_call(O.winid1, function() vim.cmd("set nonumber") end)
	end

	-- update winid to ensure validity
	function O.update()
		if O.winid1 and not vim.api.nvim_win_is_valid(O.winid1) then
			O.winid1 = nil
		end
		if O.winid2 and not vim.api.nvim_win_is_valid(O.winid2) then
			O.winid2 = nil
		end
	end

	-- delete windows
	function O.delete()
		if O.winid1 then
			vim.api.nvim_win_close(O.winid1, false)
		end
		if O.winid2 then
			vim.api.nvim_win_close(O.winid2, false)
		end
		vim.api.nvim_buf_delete(O.bufnr1, {force=true})
		vim.api.nvim_buf_delete(O.bufnr2, {force=true})
		for i = 1,3 do
			vim.api.nvim_del_autocmd(cmds[i])
		end
	end

	-- initialization code
	O.resume()
	cmds[1] = vim.api.nvim_create_autocmd({"BufEnter", "BufWinEnter"}, {
		group = id,
		callback = O.update
	})
	cmds[2] = vim.api.nvim_create_autocmd({"WinClosed", "TermClose"}, {
		group = id,
		callback = O.delete,
		buffer = O.bufnr1
	})
	cmds[3] = vim.api.nvim_create_autocmd({"WinClosed", "TermClose"}, {
		group = id,
		callback = O.delete,
		buffer = O.bufnr2
	})
	return O
end

return M
