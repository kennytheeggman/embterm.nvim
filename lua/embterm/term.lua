
local cursor = require("lua.embterm.cursor")

local G = {}

function G.new(bunfr, line, lines)
	local O = {}
	local height = lines
	local ns = vim.api.nvim_create_namespace("embterm")
	local ext

	function O.enable()
		local t = {}
	for i = 1, height do
			t[i] = {{""}}
		end
		ext = vim.api.nvim_buf_set_extmark(bunfr, ns, line-1, 0, {
			virt_text_win_col = 0,
			virt_text = {{""}},
			virt_lines = t
		})
		assert(ext ~= nil, "Embterm: Setting extmark failed")
	end
	function O.disable()
		if ext == nil then
			return
		end
		vim.api.nvim_buf_del_extmark(bunfr, ns, ext)
	end
	O.delete = O.disable
	--/// document the following function
	function O.set_lines(num_lines)
		height = num_lines
		O.disable()
		O.enable()
	end
	function O.get_lines()
		return height
	end
	return O
end

local D = {}

function D.new(parent, config)
	local O = {}
	O.pbufn = parent
	O.cmd = config.cmd
	O.differ = config.differ
	O.offset = config.offset
	-- init selection
	O.selection = cursor.visual(O.pbufn, config.priv)
	if O.selection == nil then
		O.selection = cursor.normal(O.pbufn)
	end
	assert(O.selection ~= nil, "Embterm: Selection not found")
	O.text = vim.api.nvim_buf_get_lines(O.pbufn, O.selection.start-1, O.selection.last, false)
	-- create buffer
	O.bufnrs = {
		vim.api.nvim_create_buf(false, true),
		vim.api.nvim_create_buf(false, true),
		vim.api.nvim_create_buf(false, true)
	}
	vim.api.nvim_buf_set_lines(O.bufnrs[2], 0, 1, false, O.text)
	O.visible = false
	-- add virtual text
	O.ghost = G.new(O.pbufn, O.selection.last, 1)
	O.ghost.enable()

	local cmds = {}
	local prefocus
	local term_opened = false

	-- clean up the object
	function O.delete()
		-- close windows
		for _, bufnr in ipairs(O.bufnrs) do
			local wins = vim.fn.win_findbuf(bufnr)
			for _, win in ipairs(wins) do
				vim.api.nvim_win_close(win, true)
			end
			-- delete buffer
			if vim.api.nvim_buf_is_valid(bufnr) then
				vim.api.nvim_buf_delete(bufnr, { force = true })
			end
		end
		O.ghost.delete()
		for _, cmd in ipairs(cmds) do
			vim.api.nvim_del_autocmd(cmd)
		end
	end
	-- update callback
	function O.update()
		-- close windows
		for _, bufnr in ipairs(O.bufnrs) do
			local wins = vim.fn.win_findbuf(bufnr)
			for _, win in ipairs(wins) do
				vim.api.nvim_win_close(win, true)
			end
		end
		local winid = vim.fn.bufwinid(O.pbufn)
		if winid == -1 then
			O.visible = false
			return
		end
		-- get selection
		local screen_selection = cursor.relative(O.pbufn, O.selection)
		assert(screen_selection ~= nil, "Embterm: Unreachable control flow")

		local other = screen_selection.last
		local clamped_selection = cursor.clamp(O.pbufn, screen_selection)
		local clamped_other = cursor.clamp(O.pbufn, { start = other, last = other})
		assert(clamped_selection ~= nil, "Embterm: Unreachable control flow")
		assert(clamped_other ~= nil, "Embterm: Unreachable control flow")
		-- update visibility status
		if clamped_selection.start == clamped_selection.last and clamped_other.start == clamped_other.last then
			O.visible = false
			return
		end
		O.visible = true
		-- create window
		local width = vim.api.nvim_win_get_width(winid)
		local win1 = vim.api.nvim_open_win(O.bufnrs[1], false, {
			relative = 'win',
			win = winid,
			width = math.floor(width / 2) + 2,
			height = clamped_selection.last - clamped_selection.start,
			col = 0,
			row = clamped_selection.start,
			focusable = false,
			zindex = 45
		})
		local win2 = vim.api.nvim_open_win(O.bufnrs[2], false, {
			relative = 'win',
			win = winid,
			width = width - math.floor(width / 2) - 2,
			height = clamped_selection.last - clamped_selection.start,
			col = math.floor(width / 2) + 2,
			row = clamped_selection.start,
			style = 'minimal',
			focusable = false,
			zindex = 45
		})
		local win3 = vim.api.nvim_open_win(O.bufnrs[3], false, {
			relative = 'win',
			win = winid,
			width = width,
			height = 1,
			col = 0,
			row = clamped_other.start,
			style = 'minimal',
			focusable = false,
			zindex = 45
		})
		vim.api.nvim_win_call(win1, function() vim.cmd("diffthis") end)
		vim.api.nvim_win_call(win1, function() vim.opt.signcolumn = 'no' end)
		vim.api.nvim_win_call(win2, function() vim.cmd("diffthis") end)
		if screen_selection.start < 0 then
			local offset = -screen_selection.start + 1
			-- local view1 = cursor.screentorow(O.bufnrs[1], offset)
			-- vim.api.nvim_win_call(win1, function() vim.fn.winrestview(view1) end)
			local view2 = cursor.screentorow(O.bufnrs[2], offset)
			vim.api.nvim_win_call(win2, function() vim.fn.winrestview(view2) end)
		end
		if not term_opened then
			vim.api.nvim_win_call(win3, function() 
				vim.fn.termopen(O.cmd)
				term_opened = true
			end)
			vim.api.nvim_win_call(win2, function() vim.cmd("set autoread | call feedkeys(\'lh\')") end)
			vim.api.nvim_win_call(win2, function() vim.cmd("set updatetime=100") end)
			local timer = vim.loop.new_timer()
			timer:start(500, 0, vim.schedule_wrap(function()
				vim.api.nvim_win_call(win1, function() vim.cmd(O.differ) end)
			end))
		end
	end

	function O.focus()
		local winid = vim.fn.bufwinid(O.bufnrs[1])
		local pwini = vim.fn.bufwinid(O.pbufn)
		if pwini == -1 then
			return
		end
		prefocus = vim.api.nvim_win_get_cursor(pwini)
		if winid == -1 then
			return
		end
		vim.api.nvim_set_current_win(winid)
		local view = vim.fn.winsaveview()
		view.topline = 1
		vim.api.nvim_win_call(winid, function() vim.fn.winrestview(view) end)
	end

	function O.defocus()
		local winid = vim.fn.bufwinid(O.bufnrs[1])
		local pwini = vim.fn.bufwinid(O.pbufn)
		if winid == -1 then
			return
		end

		vim.api.nvim_set_current_win(pwini)
		if prefocus == nil then
			return
		end
		vim.api.nvim_win_set_cursor(pwini, prefocus)
	end

	for i, bufnr in ipairs(O.bufnrs) do
		cmds[i] = vim.api.nvim_create_autocmd({ "TermClose", "QuitPre" }, {
			buffer = bufnr,
			callback = O.delete
		})
	end
	cmds[3] = vim.api.nvim_create_autocmd({ "BufWinLeave" } , {
		callback = function() vim.schedule(function()
			O.update()
		end) end
	})
	cmds[4] = vim.api.nvim_create_autocmd({ "BufWinEnter", "WinScrolled", "BufWinLeave" }, {
		buffer = O.pbufn,
		callback = O.update
	})
	cmds[5] = vim.api.nvim_create_autocmd({ "CursorMoved" }, {
		buffer = O.pbufn,
		callback = function()
			local pos = cursor.normal(O.pbufn)
			if pos == nil then
				return nil
			end
			local pwini = vim.fn.bufwinid(O.pbufn)
			if pwini == -1 then
				return
			end
			if pos.start <= O.selection.last and pos.start >= O.selection.start then
				O.focus()
			end
		end
	})
	cmds[6] = vim.api.nvim_create_autocmd({ "CursorMoved" }, {
		buffer = O.bufnrs[1],
		callback = vim.schedule_wrap(function()
			local pwini = vim.fn.bufwinid(O.pbufn)
			if pwini == -1 then
				return
			end
			local winid = vim.fn.bufwinid(O.bufnrs[1])
			if winid == -1 then
				return
			end
			O.focus()
			local height = vim.api.nvim_win_get_height(winid)
			local h2 = vim.api.nvim_win_get_height(pwini)
			if height >= h2-2 then
				return
			end
			-- local view = vim.api.nvim_win_call(winid, function() vim.fn.winsaveview(winid) end)
			vim.schedule(function() 
				local pview = vim.api.nvim_win_call(pwini, vim.fn.winsaveview) 
				local pos = cursor.normal(O.bufnrs[1])
				assert(pos ~= -1, "Embterm: Unreachable Control Flow")
				local new_pos = { start=O.selection.start, last=O.selection.start}
				local screen_pos = cursor.relative(O.pbufn, new_pos)
				assert(screen_pos ~= -1, "Embterm: Unreachable Control Flow")
				local tl = pview.topline
				local h = vim.api.nvim_win_get_height(pwini)
				local should = math.floor(h / 2)
				local is = screen_pos.start + pos.start - 1
				local diff = is - should
				local attempt = tl + diff
				print(attempt, is, new_pos.start)
				local nview = { topline=math.max(1, attempt) }
				vim.api.nvim_win_call(pwini, function() vim.fn.winrestview(nview) end)
				O.focus()
			end)
			-- vim.schedule(function() vim.api.nvim_win_call(pwini, function()
			-- 	vim.cmd("norm! zz")
			-- end) end)
		end)
	})
	cmds[7] = vim.api.nvim_create_autocmd({ "TextChanged", "TextChangedI" }, {
		buffer = O.bufnrs[1],
		callback = function()
			local lines = vim.api.nvim_buf_line_count(O.bufnrs[1])
			local lines2 = vim.api.nvim_buf_line_count(O.bufnrs[2])
			O.ghost.set_lines(math.max(0, lines - lines2) + 1)
			O.update()
			O.focus()
		end
	})
	cmds[7] = vim.api.nvim_create_autocmd({ "CursorHold" }, {
		buffer = O.bufnrs[1],
		callback = function()
			vim.cmd("checktime")
		end
	})
	local function keymap(key, other, bloc, destination)
		vim.api.nvim_buf_set_keymap(O.bufnrs[1], 'n', key, "", {
			callback = function()
				local pos = cursor.normal(O.bufnrs[1])
				if pos == nil then 
					return
				end
				if pos.start == bloc() then
					O.defocus()
					local pwini = vim.fn.bufwinid(O.pbufn)
					if pwini == -1 or prefocus == nil then
						return nil
					end
					vim.api.nvim_win_set_cursor(pwini, destination())
				else
					vim.cmd("norm! " .. other)
				end
			end,
			noremap = true
		})
	end
	local num_lines = function() return vim.api.nvim_buf_line_count(O.bufnrs[1]) end
	keymap("j", "k", function() return 1 end, function() return {O.selection.start - 1, prefocus[2]} end)
	keymap("<Up>", "k", function() return 1 end, function() return {O.selection.start - 1, prefocus[2]} end)
	keymap("<C-j>", "kkkkkkkkkk", function() return 1 end, function() return {math.max(1, O.selection.start - 10), prefocus[2]} end)
	keymap("k", "j", num_lines, function() return {O.selection.last + 1, prefocus[2]} end)
	keymap("<Down>", "j", num_lines, function() return {O.selection.last + 1, prefocus[2]} end)
	keymap("<C-k>", "jjjjjjjjjj", num_lines, function() return {math.min(vim.api.nvim_buf_line_count(O.pbufn), O.selection.last + 10), prefocus[2]} end)
	return O
end

return D
