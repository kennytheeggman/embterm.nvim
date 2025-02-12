local sync = {}
local utils = require('lua.embterm.utils')

function sync.new(source, destination, start_row, end_row)
	local O = {}
	-- source buffer info
	O.src = source
	-- destination buffer info
	O.dest = destination
	-- syncing text data
	O.text = {}
	O.fill = {}
	O.length = vim.api.nvim_buf_line_count(source)
	-- restore info
	local exts = {}
	local overwrite = vim.api.nvim_buf_get_lines(destination, start_row-1, end_row, false)
	local ns = vim.api.nvim_create_namespace("embterm")
	local autocmds = {}
	-- extmarks
	O.src_start_ext = vim.api.nvim_buf_set_extmark(O.src, ns, 0, 0, {})
	O.src_end_ext = vim.api.nvim_buf_set_extmark(O.src, ns, O.length-1, 0, {})
	O.dest_start_ext = vim.api.nvim_buf_set_extmark(O.dest, ns, start_row, 0, {})
	O.dest_end_ext = vim.api.nvim_buf_set_extmark(O.dest, ns, end_row, 0, {})

	local function _update_exts()
		-- update length
		O.length = vim.api.nvim_buf_line_count(source)
		-- update source last ext for bounds checks
		local src_last = vim.api.nvim_buf_get_extmark_by_id(O.src, ns, O.src_end_ext, {})[1]
		if src_last ~= O.length-1 then
			vim.api.nvim_buf_del_extmark(O.src, ns, O.src_end_ext)
			O.src_end_ext = vim.api.nvim_buf_set_extmark(O.src, ns, O.length-1, 0, {})
		end
		-- update destination last ext for bounds checks
		local dest_last = vim.api.nvim_buf_get_extmark_by_id(O.dest, ns, O.dest_end_ext, {})[1]
		if dest_last < start_row then
			vim.api.nvim_buf_del_extmark(O.dest, ns, O.dest_end_ext)
			O.dest_end_ext = vim.api.nvim_buf_set_extmark(O.dest, ns, start_row, 0, {})
		end
	end

	local function _update(bufnr, start_ext, end_ext, update_fills, offset)
		O.text = {}
		O.fill = {}
		local start = vim.api.nvim_buf_get_extmark_by_id(bufnr, ns, start_ext, {})[1]
		local last = vim.api.nvim_buf_get_extmark_by_id(bufnr, ns, end_ext, {})[1]
		-- get length
		O.length = last - start + 1
		-- get text
		O.text = vim.api.nvim_buf_get_lines(bufnr, start - 1 + offset, last + offset, false)
		-- get fills
		if not update_fills then return end
		local winid = utils.win_from_buf(bufnr)
		if winid == nil then return nil end
		for i = 0, O.length-1 do
			local fill = vim.api.nvim_win_text_height(winid, {
				start_row = i + start,
				end_row = i + start,
			}).fill
			O.fill[i+1] = fill
		end
	end
	local function _copy(bufnr, start_ext, end_ext, update_fills, offset)
		-- get bounds
		local start = vim.api.nvim_buf_get_extmark_by_id(bufnr, ns, start_ext, {})[1]
		local last = vim.api.nvim_buf_get_extmark_by_id(bufnr, ns, end_ext, {})[1]
		-- copy text 
		vim.api.nvim_buf_set_lines(bufnr, start - 1 + offset, last + offset, false, O.text)
		-- copy fills
		if not update_fills then return end
		for i = 0, O.length-1 do
			local vt = {}
			for j = 1, O.fill[i+1] do
				vt[j] = {{""}}
			end
			exts[i+1] = vim.api.nvim_buf_set_extmark(bufnr, ns, start + i, 0, {
				virt_lines = vt
			})
		end
	end

	function O.update_from_source()
		-- set start extmarks
		vim.api.nvim_buf_del_extmark(O.src, ns, O.src_start_ext)
		vim.api.nvim_buf_del_extmark(O.dest, ns, O.dest_start_ext)
		O.src_start_ext = vim.api.nvim_buf_set_extmark(O.src, ns, 0, 0, {})
		O.dest_start_ext = vim.api.nvim_buf_set_extmark(O.dest, ns, start_row, 0, {})
		-- update end extmarks
		_update_exts()
		-- update text and fills
		_update(O.src, O.src_start_ext, O.src_end_ext, true, 1)
	end
	function O.update_from_dest()
		-- set start extmarks
		vim.api.nvim_buf_del_extmark(O.src, ns, O.src_start_ext)
		vim.api.nvim_buf_del_extmark(O.dest, ns, O.dest_start_ext)
		O.src_start_ext = vim.api.nvim_buf_set_extmark(O.src, ns, 0, 0, {})
		O.dest_start_ext = vim.api.nvim_buf_set_extmark(O.dest, ns, start_row, 0, {})
		-- update text and fills
		_update(O.dest, O.dest_start_ext, O.dest_end_ext, false, 0)
		-- update end extmarks
		_update_exts()
	end

	function O.copy_to_dest()
		-- copy text and fills to destination buffer
		_copy(O.dest, O.dest_start_ext, O.dest_end_ext, true, 0)
	end

	function O.copy_to_source()
		-- copy text and fills to source buffer
		_copy(O.src, O.src_start_ext, O.src_end_ext, false, 1)
	end

	function O.restore()
		-- clear lines so we can reset any changes
		local start = vim.api.nvim_buf_get_extmark_by_id(O.dest, ns, O.dest_start_ext, {})[1]
		local last = vim.api.nvim_buf_get_extmark_by_id(O.dest, ns, O.dest_end_ext, {})[1]
		vim.api.nvim_buf_set_lines(O.dest, start-1, last, false, overwrite)
		for _, ext in ipairs(exts) do
			vim.api.nvim_buf_del_extmark(O.dest, ns, ext)
		end
	end

	function O.delete()
		-- reset all lines to before overwrite
		local start = start_row
		local last = vim.api.nvim_buf_get_extmark_by_id(O.dest, ns, O.dest_end_ext, {})[1]
		vim.schedule(function() vim.api.nvim_buf_set_lines(O.dest, start-1, last, false, overwrite) end)
		-- delete extmarks
		for _, ext in ipairs(exts) do
			vim.api.nvim_buf_del_extmark(O.dest, ns, ext)
		end
		-- delete extmarks and autocmds
		if vim.api.nvim_buf_is_valid(O.src) then
			vim.api.nvim_buf_del_extmark(O.src, ns, O.src_start_ext)
			vim.api.nvim_buf_del_extmark(O.src, ns, O.src_end_ext)
			vim.api.nvim_buf_del_extmark(O.dest, ns, O.dest_start_ext)
			vim.api.nvim_buf_del_extmark(O.dest, ns, O.dest_end_ext)
			vim.api.nvim_del_autocmd(autocmds[1])
			vim.api.nvim_del_autocmd(autocmds[3])
		end
		vim.api.nvim_del_autocmd(autocmds[2])
	end

	-- init the copy
	O.restore()
	O.update_from_source()
	O.copy_to_dest()

	-- define autocmds
	autocmds[1] = vim.api.nvim_create_autocmd({ "TextChanged", "TextChangedI" }, {
		buffer = O.src,
		callback = function()
			O.restore()
			O.update_from_source()
			O.copy_to_dest()
		end
	})
	autocmds[2] = vim.api.nvim_create_autocmd({ "TextChanged", "TextChangedI" }, {
		buffer = O.dest,
		callback = function()
			if vim.api.nvim_buf_is_valid(O.src) then
				O.update_from_dest()
				O.copy_to_source()
			else
				vim.schedule(O.delete) -- delete must be scheduled in case buffer is hidden
			end
		end
	})
	autocmds[3] = vim.api.nvim_create_autocmd({ "BufDelete" }, {
		buffer = O.src,
		callback = function()
			O.restore()
			vim.schedule(O.delete) -- delete must be scheduled in case buffer is hidden
		end
	})

	return O
end

return sync
