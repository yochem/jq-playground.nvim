# jq-playground.nvim

> Interact with jq in Neovim using interactive buffers

![Example screenshot](example/screenshot.png)

Like [jqplay.org](https://jqplay.org) or Neovim's builtin Treesitter playground
([`:InspectTree`](https://neovim.io/doc/user/treesitter.html#%3AInspectTree)).
Also supports YAML via `yq` and or many others if you
[configure](#configuration) it to use [fq](https://github.com/wader/fq) and set
output filetype appropriately.

## Installation

This plugin requires Nvim 0.10+.

The GitHub repository is at `"yochem/jq-playground.nvim"`. Use that in your
package manager. For example with
[Lazy.nvim](https://github.com/folke/lazy.nvim):

```lua
{ "yochem/jq-playground.nvim" }
```

The plugin is lazy-loaded on `:JqPlayground` and does not require any
lazy-loading by the user.

## Configuration

All possible configuration and the default values can be found in
[`config.lua`](./lua/jq-playground/config.lua), but this is it:

```lua
-- This is the default. No setup() is required if you use the default.
{
  cmd = { "jq" },
  output_window = {
    split_direction = "right",
    width = nil,
    height = nil,
    scratch = true,
    filetype = "json",
    name = "jq output",
  },
  query_window = {
    split_direction = "below",
    width = nil,
    height = 0.3,
    scratch = false,
    filetype = "jq",
    name = "jq query editor",
  },
  disable_default_keymap = false,
}
```

- `cmd`: (path to) jq executable and custom flags you might add. This can be
  another jq implementation like [gojq](https://github.com/itchyny/gojq) or
  [jaq](https://lib.rs/crates/jaq). **NOTE**: this is ignored and set to `yq`
  when the input filetype is detected as YAML. This behaviour might change in
  the future.
- `split_direction`: can be `"left"`, `"right"`, `"above"` or `"below"`. The
  split direction of the output window is relative to the input window, and
  that of the query window is relative to the output window (they open after
  each other).
- `width` and `height`:
  - `nil`: use the default: split in half
  - `0-1`: percentage of current width/height
  - `>1`: absolute width/height in number of characters or lines
- `scratch`: if the buffer should be a [scratch
  buffer](https://neovim.io/doc/user/windows.html#scratch-buffer).
- `disable_default_keymap`: disables default `<CR>` map in the query window

There are two commands that can be remapped: the user-command `:JqPlayground`
that starts the playground, and `<Plug>(JqPlaygroundRunQuery)`, that runs the
current query when pressed with the cursor in the query window. Remap them the
following way:

```lua
-- start the playground
vim.keymap.set("n", "<leader>jq", vim.cmd.JqPlayground)

-- when in the query window, run the jq query
vim.keymap.set("n", "R", "<Plug>(JqPlaygroundRunQuery)")
```

## Usage

Navigate to a JSON file, and execute the command `:JqPlayground`. Two scratch
buffers will be opened: a buffer for the JQ-filter and one for displaying the
results. Simply press `<CR>` (enter), or your keymap from setup, in the query
window to refresh the results buffer.

You can also provide a filename to the `:JqPlayground` command. This is useful
if the JSON file is very large and you don't want to open it in Neovim
directly:

```vim
:JqPlayground sample.json
```

## Tips

Some random tips that you may find useful while using this plugin.

If you have a saved jq program that you want to load into the filter window,
then run:

```vim
:r path/to/some/query.jq
```

If you want to save the current query or output json, navigate to that buffer
and run:

```vim
:w path/to/save/query.jq
" or for the output json:
:w path/to/save/output.json
```

Start the jq editor from the command line without loading the input file:

```
$ nvim +'JqPlayground input.json'
$ # or put this in your bashrc:
$ jqplay() { nvim +"JqPlayground $1"; }
```

## Credits

This is a fork of [jrop/jq.nvim](https://github.com/jrop/jq.nvim). All work
done prior to commit 4c24eb910752ec59585dd90cf20af80a9c60c1e8 are licensed
under the MIT license by them. Original license is in the linked repository.
