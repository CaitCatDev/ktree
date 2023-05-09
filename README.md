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

## TODO: 
- [] Clean up code
- [] Add ablility to create new dirs or files 
- [] Add rename
- [] Currently user config is not supported 
