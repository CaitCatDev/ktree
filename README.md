# ktree:
A simple lua file manager for NVIM

## How to install

add a entry for your plugin manager or manually install it.
For example you could place it `~/.config/nvim/lua/ktree`

or e.g. using a plugin manager like packer
```lua
    use { "CaitCatDev/ktree.git" }

    --Later in plugin setup
    require("ktree").setup({})
```

## How to use:

### Nvim User commands:

- :KTreeOpen (Open the tree in a window)
- :KTreeClose (Close the open tree window)
- :KTreeRefresh (Refresh the contents of the tree)

### Nvim keybinds:
- a (Add a file at the current cursor postions)
- r (Refresh the tree)
- d (Remove the file/dir under the cursor)
- <CR> (Open the current file/directory)


## How to configure:
An example configuration is here and this is the normal default config that we use.
```lua
	require("ktree").setup({
		symbols = {
			['directory'] = '',
			['file'] = '',
		}

		window = {
			width = 25,
		},

		colors = {
			win_selfg = 0xf8f82,
			win_selbg = "purple",
			ktree_file = "cyan",
			ktree_dir = "purple",
			ktree_cwd = "green",
		},

		shiftwidth = 2,
		tabstop = 2,
		showwin = false,
	})
```

## TODO:
- [] Clean up code
- [x] Add ablility to create new dirs or files
- [] Add rename
- [x] Currently user config is not supported
- [] implement changing directory
