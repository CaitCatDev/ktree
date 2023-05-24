local M = { }

local config = {
	symbols = {
		['directory'] = '',
		['file'] = '',
	},

	window = {
		width = 25,
	},

	--Colors
	colors = {
		win_selfg = 0xf8f8f2,
		win_selbg = "purple",
		ktree_file = "cyan",
		ktree_dir = "purple",
		ktree_cwd = "green"
	},

	shiftwidth = 2,
	tabstop = 2,
	showwin = false,
}

local state = { }

-- Example a file named /home/cat/stuff.c
--Node Struct layout
--Name: String = stuff.c
--Type: String = "File"
--Children: Node List = Nil
--Open: Boolean = True
--parent: String = "/home/cat"
--

local nodes = { }

local state = { }

local function merge_configs(user_config)
	config = vim.tbl_deep_extend("force", config, user_config)
end


local function create_node(nodeName, nodeType, nodeOpen, nodePath, depth)
	
	local node = {
	name = nodeName,
	type = nodeType,
	children = { },
	open = nodeOpen,
	parent = nodePath,
	depth = depth
	}

	return node
end

local function scandir(path, nodeTable, pos, depth) 
	local fd = vim.loop.fs_scandir(path)
	if fd then
		while true do
			name, typ = vim.loop.fs_scandir_next(fd)
			if name == nil then
				break
			end
			table.insert(nodeTable, pos, create_node(name, typ, false, path, depth))
			pos = pos + 1;
		end
	end
end

local function ktree_close_dir(row)
	local to_remove = {}

	if nodes[row - 1].open ~= true then
		return
	end

	local parent = nodes[row].parent


	for i,v in ipairs(nodes) do
		if parent ~= v.parent then
			table.insert(to_remove, v)
		end
	end

	nodes[row - 1].open = false;
	nodes = to_remove
end

local function ktree_open_dir(row)
	if nodes[row-1].open then
		ktree_close_dir(row)
		return
	end

	local cwd = nodes[row - 1].parent;
	print(nodes[row - 1].name)

	nodes[row-1].open = true;
	scandir(cwd .. '/' .. nodes[row - 1].name, nodes, row, nodes[row - 1].depth + 1)
end

local function ktree_find_node_and_open(list, node)
	for i, v in ipairs(list) do
		if v.name == node.name then
			v.open = true
			scandir(v.parent .. "/" .. v.name, new_list, i+1, v.depth + 1)
			return
		end
	end
end

local function ktree_refresh_window()
	local row,col = unpack(vim.api.nvim_win_get_cursor(state.win))
	if state.open == false then
		return
	end
	new_list = { }

	scandir(vim.fn.getcwd(), new_list, 1, 1)
	
	for i, v in ipairs(nodes) do
		if v.open then
			ktree_find_node_and_open(new_list, v);
		end
	end

	vim.api.nvim_buf_set_option(state.buf, 'modifiable', true)

	vim.api.nvim_buf_set_lines(state.buf, 0, -1, true, {})
	vim.api.nvim_buf_set_lines(state.buf, 0, 0, false, {vim.fn.getcwd()})

	vim.api.nvim_buf_add_highlight(state.buf, -1, "KTreeCWD", 0, 0, -1)

	for k, v in pairs(new_list) do
		local line = ""
		
		for i = 1, v.depth do
			line = line .. '\t'
		end
		
		line = line .. config.symbols[v.type] .. " " .. v.name
		vim.api.nvim_buf_set_lines(state.buf, k, k, true, {line})
		if v.type == 'file' then
			vim.api.nvim_buf_add_highlight(state.buf, -1, "KTreeFile", k, 0, -1)
		elseif v.type == 'directory' then
			vim.api.nvim_buf_add_highlight(state.buf, -1, "KTreeDir", k, 0, -1)

		end
	end

	nodes = new_list

	vim.api.nvim_buf_set_option(state.buf, 'modifiable', false)
	vim.api.nvim_win_set_cursor(state.win, {row, col})
end

local function ktree_add_file(input)
	local row, col = unpack(vim.api.nvim_win_get_cursor(state.win))
	local parent = nodes[row - 1].parent
	if nodes[row-1].open then
		parent = parent .. "/" .. nodes[row - 1].name
	end
	local char = string.sub(input, -1);

	print(parent .. "/" .. input .. " " .. char)

	if char == '/' then
		vim.loop.fs_mkdir(parent .. "/" .. input, 510)
	else
		vim.loop.fs_open(parent .. "/" .. input, "w", 420);
	end

	ktree_refresh_window()
end

local function ktree_remove_file(input)
	local row, col = unpack(vim.api.nvim_win_get_cursor(state.win))
	local fname = nodes[row - 1].name
	local parent = nodes[row - 1].parent

	input = string.lower(input)
	if input == 'n' then
		return
	end

	if input ~= 'y' then
		print(input .. " is not a valid option")
		return
	end
	print(parent .. "/" .. fname)
	if nodes[row - 1].type == 'directory' then
		vim.loop.fs_rmdir(parent .. "/" .. fname)
	else
		vim.loop.fs_unlink(parent .. "/" .. fname)
	end

	ktree_refresh_window()
end

local function ktree_remove_file_input()
	vim.ui.input({prompt = "Are you sure (y/n): "}, ktree_remove_file)
end

local function ktree_add_file_input() 
	vim.ui.input({prompt = "File To Create: "}, ktree_add_file)
end

local function ktree_winlist_rm(list, value)
	for i,win in ipairs(list) do
		if win == value then
			table.remove(list, i)
		end
	end
end

local function highlight(group, fg, bg)
	vim.api.nvim_set_hl(0, group, {
		fg = fg,
		bg = bg,
	})
end

local function ktree_open_file(row)
	local winlist = vim.api.nvim_tabpage_list_wins(0)
	local save_status = { }

	if config.showwin == false then
		ktree_winlist_rm(winlist, state.win)
	end

	--Save the old status line and replace it
	for i, win in ipairs(winlist) do
		print(win, i)
		table.insert(save_status, i, vim.wo[win].statusline)
		vim.wo[win].statusline = string.format("%%#KTreeWinSelect#%%=%c%%=", i + 64)
	end

	vim.cmd("redraw!")
	local char = vim.fn.getchar()

	--Restore the status lines of the windows.
	for i, win in ipairs(winlist) do
	vim.wo[win].statusline = save_status[i]
	end

	if type(char) ~= "number" then
		print("Unknown multi byte input")
		return
	end

	--Convert ASCII Code to number
	char = char - 96

	if char <= #winlist and char > 0 then
	vim.api.nvim_set_current_win(winlist[char])
	vim.cmd("e " .. nodes[row-1].parent .. "/" .. nodes[row-1].name)
	else
	print("Unknown input " .. char + 96);
	end

end

local function ktree_open_node()
	local row, col = unpack(vim.api.nvim_win_get_cursor(state.win))
	if row == 1 then
		ktree_refresh_window()
		return
	end

	print(nodes[row - 1].name)

	if nodes[row - 1].type == 'directory' then
		ktree_open_dir(row)
	elseif nodes[row - 1].type == 'file' then
		ktree_open_file(row)
	end


	ktree_refresh_window()
end

local function ktree_open_window()
	if state.open == true then
	return
	end
	vim.cmd("vsplit");

	vim.api.nvim_win_set_buf(0, state.buf)

	state.win = vim.api.nvim_get_current_win()
	vim.wo[state.win].list = false
	vim.wo[state.win].wrap = false

	vim.cmd("set nonumber")
	vim.api.nvim_win_set_width(state.win, config.window.width)

	state.open = true
	ktree_refresh_window()
end


local function ktree_close_window()
	if state.open == false then
	return
	end

	vim.api.nvim_win_close(state.win, false);
	state.win = nil
	state.open = false
end

local function ktree_setup(user_config)
	merge_configs(user_config)

	state.buf = vim.api.nvim_create_buf(false, true)
	scandir(vim.fn.getcwd(), nodes, 1, 1)

	vim.api.nvim_create_user_command("KTreeOpen", ktree_open_window, {})
	vim.api.nvim_create_user_command("KTreeClose", ktree_close_window, {})
	vim.api.nvim_create_user_command("KTreeRefresh", ktree_refresh_window, {});

	vim.api.nvim_buf_set_keymap(state.buf, "", "a", "", { 
		noremap = false,
		callback =  ktree_add_file_input,
		desc = "add file at cursor pos"
	})

	vim.api.nvim_buf_set_keymap(state.buf, "", "<CR>", "", {
		noremap = false,
		callback = ktree_open_node,
		desc = "Open the current line node",
	})

	vim.api.nvim_buf_set_keymap(state.buf, "", "r", "", {
		noremap = false,
		callback = ktree_refresh_window,
		desc = "Open the current line node",
	})

	vim.api.nvim_buf_set_keymap(state.buf, "", "d", "", {
		noremap = false,
		callback =ktree_remove_file_input,
		desc = "Delete the file under the cursor"
	})

	--Setup highlighting 
	--TODO: set highlight namespace
	highlight("KTreeFile", config.colors.ktree_file, "NONE")
	highlight("KTreeDir", config.colors.ktree_dir, "NONE")
	highlight("KTreeWinSelect", config.colors.win_selfg, config.colors.win_selbg)
	highlight("KTreeCWD", config.colors.ktree_cwd, "NONE");
	vim.api.nvim_buf_set_option(state.buf, 'modifiable', false)

	--Listen for when a window with this buffer is closed
	vim.api.nvim_create_autocmd({"WinClosed"}, {
	buffer = state.buf,
	callback = function(ev)
		state.open = false
		state.win = nil
	end
	})

	vim.api.nvim_create_autocmd({"BufWinLeave"}, {
	buffer = state.buf,
	callback = function(ev)
		state.open = false
		state.win = nil
	end
	})

-----
--	Buffer Options
-----
	vim.bo[state.buf].tabstop = config.tabstop
	vim.bo[state.buf].shiftwidth = config.shiftwidth

	vim.api.nvim_buf_set_name(state.buf, 'KTree')
end

M = {
	setup = ktree_setup,
}

return M
