-- Context Outline for Neovim: browse .context-outline/root.json in a side panel.
local M = {}

M.defaults = {
  position = "right", -- "right" or "left"
  width = 40,
  highlight = "Visual", -- highlight group for the opened line range (false to disable)
  focus_on_open = true, -- move the cursor to the code window after <CR>
  icons = { expanded = "▾", collapsed = "▸", leaf = "•" },
  claude_code_terminal = true, -- allow running Claude Code (`claude` CLI) in a terminal
  copilot_terminal = true, -- allow running GitHub Copilot CLI (`copilot`) in a terminal
  keymaps = {
    open = "<CR>",
    toggle = { "o", "za" },
    expand = "l",
    collapse = "h",
    yank_context = "<leader>yc",
    detail = "D", -- add child items with an AI CLI in a terminal
    info = "K",
    reload = "R",
    close = "q",
  },
}

M.config = vim.deepcopy(M.defaults)

local function plugin_root()
  local src = debug.getinfo(1, "S").source:sub(2)
  return vim.fs.dirname(vim.fs.dirname(vim.fs.dirname(src)))
end

-- Read a bundled prompt (media/*.md). Returns nil (and warns) if it's missing.
function M.read_prompt(file)
  local path = vim.fs.joinpath(plugin_root(), "media", file)
  local ok, lines = pcall(vim.fn.readfile, path)
  if not ok then
    vim.notify("Context Outline: missing " .. path, vim.log.levels.ERROR)
    return nil
  end
  return table.concat(lines, "\n") .. "\n"
end

-- Copy a bundled prompt for an AI tool.
function M.copy_prompt(file)
  local text = M.read_prompt(file)
  if not text then
    return
  end
  vim.fn.setreg('"', text)
  pcall(vim.fn.setreg, "+", text)
  vim.notify("Context Outline: prompt copied. Paste it into Claude Code or any AI tool opened on your project.")
end

local did_setup = false

function M.setup(opts)
  M.config = vim.tbl_deep_extend("force", vim.deepcopy(M.defaults), opts or {})
  local panel = require("context-outline.panel")
  panel.setup(M.config)
  if did_setup then
    return
  end
  did_setup = true

  vim.api.nvim_create_user_command("ContextOutline", function(a)
    if a.args == "left" or a.args == "right" then
      M.config.position = a.args
      panel.close()
      return panel.open()
    end
    panel.toggle()
  end, { nargs = "?", complete = function() return { "left", "right" } end, desc = "Toggle Context Outline panel" })
  vim.api.nvim_create_user_command("ContextOutlineBuildPrompt", function()
    M.copy_prompt("build-prompt.md")
  end, { desc = "Copy prompt to build .context-outline/root.json" })
  vim.api.nvim_create_user_command("ContextOutlineReindexPrompt", function()
    M.copy_prompt("reindex-prompt.md")
  end, { desc = "Copy prompt to reindex .context-outline/root.json" })
  vim.api.nvim_create_user_command("ContextOutlineBuild", function(a)
    require("context-outline.ai").build(a.args)
  end, {
    nargs = "?",
    complete = function()
      return require("context-outline.ai").enabled_names()
    end,
    desc = "Build .context-outline/root.json with Claude Code or Copilot in a terminal",
  })

  local group = vim.api.nvim_create_augroup("ContextOutline", { clear = true })
  vim.api.nvim_create_autocmd("BufWritePost", {
    group = group,
    pattern = "*/.context-outline/root.json",
    callback = function(ev)
      panel.on_map_written(vim.fn.fnamemodify(ev.file, ":p"))
    end,
  })
  vim.api.nvim_create_autocmd("WinEnter", { group = group, callback = panel.track_window })
  vim.api.nvim_create_autocmd({ "TabEnter", "FocusGained", "TermClose" }, {
    group = group,
    callback = function()
      vim.schedule(panel.check_changed)
    end,
  })
end

function M.toggle()
  require("context-outline.panel").toggle()
end

function M.open()
  require("context-outline.panel").open()
end

function M.close()
  require("context-outline.panel").close()
end

return M
