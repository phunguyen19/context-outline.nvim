-- Runs an AI CLI (Claude Code, Copilot) in a terminal to build the map or add detail to an item.
local M = {}

M.tools = {
  claude = {
    label = "Claude Code",
    setting = "claude_code_terminal",
    bin = "claude",
    extra_dirs = function(home)
      return { vim.fs.joinpath(home, ".claude", "local") }
    end,
    args = function(prompt)
      return { prompt }
    end,
  },
  copilot = {
    label = "Copilot",
    setting = "copilot_terminal",
    bin = "copilot",
    extra_dirs = function()
      return {}
    end,
    -- -i starts the interactive session and runs the prompt right away.
    args = function(prompt)
      return { "-i", prompt }
    end,
  },
}

M.order = { "claude", "copilot" }

local function config()
  return require("context-outline").config
end

function M.enabled(name)
  local tool = M.tools[name]
  return tool ~= nil and config()[tool.setting] ~= false
end

-- Names of the tools that are turned on, in display order.
function M.enabled_names()
  return vim.tbl_filter(M.enabled, M.order)
end

-- Neovim started from a GUI or launcher can miss where CLIs live
-- (e.g. ~/.local/bin is only added by the shell's rc files), so look further.
local cli_paths = {}
local function find_cli(tool)
  local cached = cli_paths[tool.bin]
  if cached and vim.fn.executable(cached) == 1 then
    return cached
  end
  local found = vim.fn.exepath(tool.bin)
  if found ~= "" then
    cli_paths[tool.bin] = found
    return found
  end
  local home = vim.uv.os_homedir()
  local dirs = { vim.fs.joinpath(home, ".local", "bin") }
  vim.list_extend(dirs, tool.extra_dirs(home))
  vim.list_extend(dirs, { "/opt/homebrew/bin", "/usr/local/bin" })
  for _, dir in ipairs(dirs) do
    local p = vim.fs.joinpath(dir, tool.bin)
    if vim.fn.executable(p) == 1 then
      cli_paths[tool.bin] = p
      return p
    end
  end
  -- Last try: ask the user's login shell, which loads their PATH setup.
  if vim.fn.has("win32") == 0 then
    local shell = vim.env.SHELL or "/bin/zsh"
    local ok, res = pcall(function()
      return vim.system({ shell, "-lic", "command -v " .. tool.bin }, { text = true }):wait(5000)
    end)
    if ok and res.code == 0 and res.stdout then
      local lines = vim.split(vim.trim(res.stdout), "\n")
      local p = lines[#lines]
      if p and p ~= "" and vim.fn.executable(p) == 1 then
        cli_paths[tool.bin] = p
        return p
      end
    end
  end
  return nil
end

-- Starts the CLI as the terminal's own process in a new tab, so the prompt is
-- passed as one argument with no shell quoting to worry about.
local function run(tool, cwd, prompt)
  local cli = find_cli(tool)
  if not cli then
    vim.notify(
      ("Context Outline: could not find the `%s` CLI. Install %s, then try again."):format(tool.bin, tool.label),
      vim.log.levels.ERROR
    )
    return
  end
  local cmd = vim.list_extend({ cli }, tool.args(prompt))
  vim.cmd("tabnew")
  if vim.fn.has("nvim-0.11") == 1 then
    vim.fn.jobstart(cmd, { term = true, cwd = cwd })
  else
    vim.fn.termopen(cmd, { cwd = cwd })
  end
  pcall(vim.api.nvim_buf_set_name, 0, "term://" .. tool.label)
  vim.cmd("startinsert")
end

-- Use the named tool, the only enabled one, or ask which one.
local function pick(name, cb)
  if name and name ~= "" then
    if not M.tools[name] then
      return vim.notify("Context Outline: unknown tool " .. name .. " (use claude or copilot)", vim.log.levels.ERROR)
    end
    if not M.enabled(name) then
      return vim.notify(
        ("Context Outline: %s (Terminal) is turned off (%s = false)."):format(M.tools[name].label, M.tools[name].setting),
        vim.log.levels.WARN
      )
    end
    return cb(M.tools[name])
  end
  local names = M.enabled_names()
  if #names == 0 then
    return vim.notify("Context Outline: no AI terminal tools are turned on.", vim.log.levels.WARN)
  end
  if #names == 1 then
    return cb(M.tools[names[1]])
  end
  vim.ui.select(names, {
    prompt = "Context Outline: run with",
    format_item = function(n)
      return M.tools[n].label
    end,
  }, function(choice)
    if choice then
      cb(M.tools[choice])
    end
  end)
end

-- Build the map in the project's root (where the map is, else the current directory).
function M.build(name)
  local root = require("context-outline.map").find() or vim.fn.getcwd()
  local prompt = require("context-outline").read_prompt("build-prompt.md")
  if not prompt then
    return
  end
  pick(name, function(tool)
    run(tool, root, prompt)
  end)
end

-- Ask the AI to add finer steps under one item.
-- `titles` runs from the top of the map down to the item.
function M.detail(name, root, titles, node)
  local quoted = vim.tbl_map(function(t)
    return '"' .. t .. '"'
  end, titles)
  local where = node.file and ("Its code: " .. node.file .. (node.lines and (":" .. node.lines) or "")) or ""
  local prompt = require("context-outline").read_prompt("detail-prompt.md")
  if not prompt then
    return
  end
  -- Function replacements so % in titles isn't treated as a pattern escape.
  prompt = prompt:gsub("{{PATH}}", function()
    return table.concat(quoted, " > ")
  end, 1)
  prompt = prompt:gsub("{{WHERE}}", function()
    return where
  end, 1)
  pick(name, function(tool)
    run(tool, root, prompt)
  end)
end

return M
