# context-outline.nvim

Neovim port of the Context Outline VS Code extension. Shows a project's `.context-outline/root.json` as a tree in a side panel and jumps to the code behind each step.

## Install (lazy.nvim)

```lua
{
  dir = "~/dev/personal/context-outline.nvim",
  name = "context-outline.nvim",
  cmd = { "ContextOutline", "ContextOutlineBuildPrompt", "ContextOutlineReindexPrompt" },
  keys = { { "<leader>co", "<cmd>ContextOutline<CR>", desc = "Toggle context outline" } },
  opts = {
    position = "right", -- or "left"
    width = 40,
  },
}
```

The map is found by walking up from the current directory.

## Panel keys

| Key | Action |
|---|---|
| `<CR>` | Open the item's file at its lines (lines are highlighted). Items without a file fold/unfold |
| `<leader>yc` | Yank context for the item (visual mode: every selected item) |
| `o` / `za` | Toggle fold |
| `l` / `h` | Expand / collapse (or jump to parent) |
| `K` | Show note, summary and file |
| `R` | Reload `root.json` (also reloads on save) |
| `q` | Close |

The yanked text goes to the `"` and `+` registers:

```
context mapping from @.context-outline/root.json
item: "3. the title of the item"
```

## Commands

- `:ContextOutline` toggles the panel. `:ContextOutline left|right` opens it on that side.
- `:ContextOutlineBuildPrompt` copies a prompt for your AI tool to build the map (`media/build-prompt.md`).
- `:ContextOutlineReindexPrompt` copies a prompt to update the map after code changes (`media/reindex-prompt.md`).

## Options

```lua
{
  position = "right",
  width = 40,
  highlight = "Visual",   -- group for the opened line range, false to disable
  focus_on_open = true,   -- false keeps the cursor in the panel after <CR>
  icons = { expanded = "▾", collapsed = "▸", leaf = "•" },
  keymaps = {
    open = "<CR>", toggle = { "o", "za" }, expand = "l", collapse = "h",
    yank_context = "<leader>yc", info = "K", reload = "R", close = "q",
  },
}
```

See the VS Code extension's README for the `root.json` format.
