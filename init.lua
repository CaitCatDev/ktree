local M = { } 

local config = {
    symbols = {
	['directory'] = '',
	['file'] = '',
    },
    width = 25,
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

local function ktree_refresh_window() 
    local pos = vim.api.nvim_win_get_cursor(state.win)
    if state.open == false then 
	return 
    end
   
    vim.api.nvim_buf_set_option(state.buf, 'modifiable', true)

    vim.api.nvim_buf_set_lines(state.buf, 0, -1, true, {})
    vim.api.nvim_buf_set_lines(state.buf, 0, 0, false, {vim.fn.getcwd()})
    for k, v in pairs(nodes) do
	local line = ""
	for i = 1, v.depth do
	    line = line .. '\t' 
	end
	line = line .. config.symbols[v.type] .. " " .. v.name 
	vim.api.nvim_buf_set_lines(state.buf, k, k, true, {line})
	if v.type == 'file' then
	    vim.api.nvim_buf_add_highlight(state.buf, -1, "KtreeFile", k, 0, -1)
	elseif v.type == 'directory' then 
	    vim.api.nvim_buf_add_highlight(state.buf, -1, "KtreeDir", k, 0, -1)
	end
    end

    vim.api.nvim_buf_set_option(state.buf, 'modifiable', false)
    vim.api.nvim_win_set_cursor(state.win, pos)
end


local function ktree_open_dir(row) 
    local cwd = nodes[row - 1].parent;
    print(nodes[row - 1].name)

    scandir(cwd .. '/' .. nodes[row - 1].name, nodes, row, nodes[row - 1].depth + 1)
end

local function ktree_open_file(row) 
    local winlist = vim.api.nvim_tabpage_list_wins(0)
    local save_status = { } 
    for i, win in ipairs(winlist) do
	print(win, i)
	table.insert(save_status, i, vim.wo[win].statusline)
	vim.wo[win].statusline = string.format("%%=%c%%=", i + 64)
    end
    
    vim.cmd("redraw!")
    local char =  vim.fn.getchar()

 
    for i, win in ipairs(winlist) do
	vim.wo[win].statusline = save_status[i] 
    end

    if type(char) ~= "number" then
	print("Unknown multi byte input")
	return
    end

    char = char - 96
    print(char)
 
    if char <= #winlist and char > 0 then
	vim.api.nvim_set_current_win(winlist[char])
	vim.cmd("e " .. nodes[row-1].parent .. "/" .. nodes[row-1].name)
    else 
	print("Unknown input " .. char + 96);
    end

end

local function ktree_open_node()  
    local row, col = unpack(vim.api.nvim_win_get_cursor(state.win))
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
    vim.cmd("vsplit")
    vim.api.nvim_win_set_buf(0, state.buf)
    
    state.win = vim.api.nvim_get_current_win()
    vim.cmd("set nonumber") 
    vim.api.nvim_win_set_width(state.win, config.width)

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
    state.buf = vim.api.nvim_create_buf(false, true) 
    scandir(vim.fn.getcwd(), nodes, 1, 1)
    
    vim.api.nvim_create_user_command("KtreeOpen", ktree_open_window, {})
    vim.api.nvim_create_user_command("KtreeClose", ktree_close_window, {})
    vim.api.nvim_create_user_command("KtreeRefresh", ktree_refresh_window, {}); 

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

    --Setup highlighting 
    --TODO: set highlight namespace
    vim.api.nvim_set_hl(0, "KtreeFile", {
	fg = "cyan",
	bg = "NONE",
	bold = true,
    })
    vim.api.nvim_set_hl(0, "KtreeDir", {
	fg = "purple",
	bg = "NONE",
	bold = true,
    })
    
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

    vim.api.nvim_buf_set_name(state.buf, 'Ktree')
end

M = {
    setup = ktree_setup,
}

return M
