# context-outline.nvim

Neovim port of the Context Outline VS Code extension. Shows a project's `.context-outline/root.json` as a tree in a side panel and jumps to the code behind each step.

## Install (lazy.nvim)

```lua
{
  dir = "~/dev/personal/context-outline.nvim",
  name = "context-outline.nvim",
  cmd = { "ContextOutline", "ContextOutlineBuild", "ContextOutlineBuildPrompt", "ContextOutlineReindexPrompt" },
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
| `D` | More detail child items with Claude Code / Copilot (terminal) |
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
- `:ContextOutlineBuild [claude|copilot]` builds the map with an AI CLI in a terminal (see below).
- `:ContextOutlineReindexPrompt` copies a prompt to update the map after code changes (`media/reindex-prompt.md`).

## Claude Code / Copilot (Terminal)

The plugin can start an AI CLI for you instead of copying prompts. It opens a terminal in a new tab, in the project folder, with the prompt already filled in. Each one has its own option:

- `claude_code_terminal`: needs the [`claude`](https://claude.com/claude-code) CLI on your PATH. On by default.
- `copilot_terminal`: needs the [GitHub Copilot CLI](https://github.com/github/copilot-cli) (`copilot`) on your PATH. On by default.

For each one that's on:

- `:ContextOutlineBuild [claude|copilot]` runs the CLI with the build prompt. With no argument it uses the only one that's on, or asks.
- `D` on a panel item asks the AI to read that item's code and add finer steps under it (prompt in `media/detail-prompt.md`), leaving the rest of the map alone.

The panel reloads by itself when the AI saves `root.json` (checked when you come back to the panel's tab, when Neovim regains focus, or when the AI exits).

## Options

```lua
{
  position = "right",
  width = 40,
  highlight = "Visual",   -- group for the opened line range, false to disable
  focus_on_open = true,   -- false keeps the cursor in the panel after <CR>
  icons = { expanded = "▾", collapsed = "▸", leaf = "•" },
  claude_code_terminal = true, -- false hides Claude Code from build/detail
  copilot_terminal = true,     -- false hides Copilot from build/detail
  keymaps = {
    open = "<CR>", toggle = { "o", "za" }, expand = "l", collapse = "h",
    yank_context = "<leader>yc", detail = "D", info = "K", reload = "R", close = "q",
  },
}
```

See the VS Code extension's README for the `root.json` format.
