-- The side panel: renders the map as a foldable tree and handles its keys.
local map = require("context-outline.map")

local M = {}

local ns_text = vim.api.nvim_create_namespace("context-outline")
local ns_hl = vim.api.nvim_create_namespace("context-outline-range")

local state = {
  buf = nil,
  win = nil,
  prev_win = nil, -- window to open files in
  root_dir = nil,
  map_path = nil,
  data = nil,
  expanded = {}, -- path key ("0.2.1") -> true; survives reloads
  rows = {}, -- buffer line -> { node, key, depth }
  hl_buf = nil, -- buffer holding the last range highlight
}

local config

function M.setup(cfg)
  config = cfg
end

local function valid_win(w)
  return w and vim.api.nvim_win_is_valid(w)
end

function M.is_open()
  return valid_win(state.win) and vim.api.nvim_win_get_buf(state.win) == state.buf
end

local function has_children(node)
  return type(node.children) == "table" and #node.children > 0
end

-- ---- Rendering ----------------------------------------------------------

function M.render()
  if not (state.buf and vim.api.nvim_buf_is_valid(state.buf)) then
    return
  end
  local lines, rows, marks = {}, {}, {}

  local function add(node, key, depth)
    local icon
    if has_children(node) then
      icon = state.expanded[key] and config.icons.expanded or config.icons.collapsed
    else
      icon = config.icons.leaf
    end
    local title = map.title(node)
    if depth == 0 and not node.name then
      title = vim.fs.basename(state.root_dir)
    end
    table.insert(lines, string.rep("  ", depth) .. icon .. " " .. title)
    rows[#lines] = { node = node, key = key, depth = depth }

    local hint
    if depth == 0 then
      hint = node.basedOn
    elseif node.file then
      hint = vim.fs.basename(node.file) .. (node.lines and (":" .. node.lines) or "")
    end
    if hint and hint ~= "" then
      marks[#lines] = hint
    end

    if has_children(node) and state.expanded[key] then
      for i, child in ipairs(node.children) do
        add(child, key .. "." .. i, depth + 1)
      end
    end
  end

  if state.data then
    add(state.data, "0", 0)
  else
    lines = {
      "No " .. map.MAP_REF .. " found.",
      "",
      ":ContextOutlineBuildPrompt copies a prompt",
      "for your AI tool to build the map.",
    }
    local tools = require("context-outline.ai").enabled_names()
    if #tools > 0 then
      local labels = vim.tbl_map(function(n)
        return require("context-outline.ai").tools[n].label
      end, tools)
      vim.list_extend(lines, {
        "",
        ":ContextOutlineBuild runs " .. table.concat(labels, " or "),
        "in a terminal to build it.",
      })
    end
  end

  vim.bo[state.buf].modifiable = true
  vim.api.nvim_buf_set_lines(state.buf, 0, -1, false, lines)
  vim.bo[state.buf].modifiable = false
  vim.api.nvim_buf_clear_namespace(state.buf, ns_text, 0, -1)
  for row, hint in pairs(marks) do
    vim.api.nvim_buf_set_extmark(state.buf, ns_text, row - 1, 0, {
      virt_text = { { hint, "Comment" } },
      virt_text_pos = "eol",
    })
  end
  if state.data then
    vim.api.nvim_buf_set_extmark(state.buf, ns_text, 0, 0, { end_col = #lines[1], hl_group = "Title" })
  end
  state.rows = rows
end

-- Re-read root.json (keeps fold state).
function M.reload()
  local root_dir, map_path = map.find()
  state.root_dir, state.map_path, state.data = root_dir, map_path, nil
  state.mtime = map_path and M.mtime(map_path) or nil
  if map_path then
    local data, err = map.load(map_path)
    if data then
      state.data = data
    else
      vim.notify("Context Outline: " .. err, vim.log.levels.WARN)
    end
  end
  M.render()
end

-- ---- Actions ------------------------------------------------------------

local function row_at(lnum)
  return state.rows[lnum or vim.api.nvim_win_get_cursor(0)[1]]
end

local function set_expanded(row, value)
  if not row or not has_children(row.node) then
    return
  end
  if value == nil then
    value = not state.expanded[row.key]
  end
  state.expanded[row.key] = value or nil
  local cursor = vim.api.nvim_win_get_cursor(0)
  M.render()
  pcall(vim.api.nvim_win_set_cursor, 0, cursor)
end

function M.toggle_fold()
  set_expanded(row_at(), nil)
end

function M.expand()
  set_expanded(row_at(), true)
end

-- Collapse the item, or jump to its parent when it's already collapsed / a leaf.
function M.collapse()
  local lnum = vim.api.nvim_win_get_cursor(0)[1]
  local row = row_at(lnum)
  if not row then
    return
  end
  if has_children(row.node) and state.expanded[row.key] then
    return set_expanded(row, false)
  end
  for l = lnum - 1, 1, -1 do
    local r = state.rows[l]
    if r and r.depth < row.depth then
      vim.api.nvim_win_set_cursor(0, { l, 0 })
      return
    end
  end
end

-- A normal window to show code in: the one we came from, else any other, else a new split.
local function target_win()
  if valid_win(state.prev_win) and state.prev_win ~= state.win then
    return state.prev_win
  end
  for _, w in ipairs(vim.api.nvim_tabpage_list_wins(0)) do
    if w ~= state.win and vim.api.nvim_win_get_config(w).relative == "" then
      return w
    end
  end
  vim.cmd((config.position == "left" and "botright" or "topleft") .. " vsplit")
  local w = vim.api.nvim_get_current_win()
  vim.api.nvim_win_set_width(state.win, config.width)
  return w
end

local function clear_highlight()
  if state.hl_buf and vim.api.nvim_buf_is_valid(state.hl_buf) then
    vim.api.nvim_buf_clear_namespace(state.hl_buf, ns_hl, 0, -1)
  end
  state.hl_buf = nil
end

function M.open_item()
  local row = row_at()
  if not row then
    return
  end
  local node = row.node
  if not node.file then
    return M.toggle_fold()
  end
  local path = vim.fs.joinpath(state.root_dir, node.file)
  if vim.fn.filereadable(path) == 0 then
    vim.notify("Context Outline: file not found: " .. path, vim.log.levels.ERROR)
    return
  end

  clear_highlight()
  local win = target_win()
  state.prev_win = win
  vim.api.nvim_set_current_win(win)
  vim.cmd("edit " .. vim.fn.fnameescape(path))

  local s, e = map.parse_lines(node.lines)
  if s then
    local buf = vim.api.nvim_get_current_buf()
    local last = vim.api.nvim_buf_line_count(buf)
    s, e = math.min(s, last), math.min(e, last)
    vim.api.nvim_win_set_cursor(win, { s, 0 })
    vim.cmd("normal! zt")
    if config.highlight then
      vim.api.nvim_buf_set_extmark(buf, ns_hl, s - 1, 0, {
        end_row = e - 1,
        end_col = #vim.api.nvim_buf_get_lines(buf, e - 1, e, false)[1],
        hl_group = config.highlight,
        hl_eol = true,
      })
      state.hl_buf = buf
    end
  end
  if config.focus_on_open == false then
    vim.api.nvim_set_current_win(state.win)
  end
end

local function yank(nodes)
  if #nodes == 0 then
    return
  end
  local text = map.context_block(nodes)
  vim.fn.setreg('"', text)
  pcall(vim.fn.setreg, "+", text)
  vim.notify(("Context Outline: copied %d item%s"):format(#nodes, #nodes > 1 and "s" or ""))
end

function M.yank_context()
  local row = row_at()
  if row then
    yank({ row.node })
  end
end

function M.yank_context_visual()
  local a, b = vim.fn.line("v"), vim.fn.line(".")
  if a > b then
    a, b = b, a
  end
  vim.api.nvim_feedkeys(vim.keycode("<Esc>"), "nx", false)
  local nodes = {}
  for l = a, b do
    if state.rows[l] then
      table.insert(nodes, state.rows[l].node)
    end
  end
  yank(nodes)
end

-- Titles from the top of the map down to the row's item.
local function row_titles(row)
  local titles, node = {}, state.data
  local root_title = node.name or node.title or vim.fs.basename(state.root_dir)
  table.insert(titles, root_title)
  for i in row.key:gmatch("%.(%d+)") do
    node = node.children[tonumber(i)]
    table.insert(titles, map.title(node))
  end
  return titles
end

-- Run an AI CLI in a terminal to add finer steps under the item.
function M.detail()
  local row = row_at()
  if not row then
    return
  end
  require("context-outline.ai").detail(nil, state.root_dir, row_titles(row), row.node)
end

function M.show_info()
  local row = row_at()
  if not row then
    return
  end
  local n = row.node
  local out = { map.title(n) }
  for _, part in ipairs({ n.note, n.summary, n.basedOn and ("Based on " .. n.basedOn) }) do
    if part then
      vim.list_extend(out, { "", part })
    end
  end
  if n.file then
    vim.list_extend(out, { "", "`" .. n.file .. (n.lines and (":" .. n.lines) or "") .. "`" })
  end
  vim.lsp.util.open_floating_preview(out, "markdown", { border = "rounded", max_width = 80, focus_id = "context-outline" })
end

-- ---- Window -------------------------------------------------------------

local function set_keymaps(buf)
  local km = config.keymaps
  local function map_key(lhs, fn, desc, mode)
    for _, l in ipairs(type(lhs) == "table" and lhs or { lhs }) do
      vim.keymap.set(mode or "n", l, fn, { buffer = buf, nowait = true, silent = true, desc = desc })
    end
  end
  map_key(km.open, M.open_item, "Open code")
  map_key(km.toggle, M.toggle_fold, "Toggle item")
  map_key(km.expand, M.expand, "Expand item")
  map_key(km.collapse, M.collapse, "Collapse item")
  map_key(km.yank_context, M.yank_context, "Yank context")
  map_key(km.yank_context, M.yank_context_visual, "Yank context", "x")
  if km.detail then
    map_key(km.detail, M.detail, "More detail child items with AI (terminal)")
  end
  map_key(km.info, M.show_info, "Show item details")
  map_key(km.reload, M.reload, "Reload map")
  map_key(km.close, M.close, "Close panel")
end

function M.open()
  if not config then
    require("context-outline").setup()
  end
  if M.is_open() then
    vim.api.nvim_set_current_win(state.win)
    return
  end
  state.prev_win = vim.api.nvim_get_current_win()

  state.buf = vim.api.nvim_create_buf(false, true)
  vim.bo[state.buf].bufhidden = "wipe"
  vim.bo[state.buf].swapfile = false
  vim.bo[state.buf].modifiable = false
  vim.api.nvim_buf_set_name(state.buf, "ContextOutline")
  vim.bo[state.buf].filetype = "context-outline"

  vim.cmd((config.position == "left" and "topleft" or "botright") .. " vsplit")
  state.win = vim.api.nvim_get_current_win()
  vim.api.nvim_win_set_buf(state.win, state.buf)
  vim.api.nvim_win_set_width(state.win, config.width)
  local wo = vim.wo[state.win]
  wo.winfixwidth = true
  wo.number = false
  wo.relativenumber = false
  wo.signcolumn = "no"
  wo.foldcolumn = "0"
  wo.wrap = false
  wo.list = false
  wo.spell = false
  wo.cursorline = true

  set_keymaps(state.buf)
  if not state.expanded["0"] then
    state.expanded["0"] = true
  end
  M.reload()
  vim.api.nvim_win_set_cursor(state.win, { 1, 0 })
end

function M.close()
  if not M.is_open() then
    return
  end
  if #vim.api.nvim_tabpage_list_wins(0) == 1 then
    vim.cmd("enew")
  else
    vim.api.nvim_win_close(state.win, true)
  end
  state.win = nil
end

function M.toggle()
  if M.is_open() then
    M.close()
  else
    M.open()
  end
end

-- Remember the last code window, so <CR> opens files there.
function M.track_window()
  local w = vim.api.nvim_get_current_win()
  if w ~= state.win and vim.api.nvim_win_get_config(w).relative == "" then
    state.prev_win = w
  end
end

function M.mtime(path)
  local st = vim.uv.fs_stat(path)
  return st and (st.mtime.sec .. "." .. st.mtime.nsec) or nil
end

-- Reload if root.json was created or changed outside Neovim (e.g. by an AI CLI).
function M.check_changed()
  if not M.is_open() then
    return
  end
  local _, map_path = map.find()
  if map_path ~= state.map_path or (map_path and M.mtime(map_path) ~= state.mtime) then
    M.reload()
  end
end

function M.on_map_written(path)
  local real = vim.uv.fs_realpath
  if M.is_open() and state.map_path and real(path) == real(state.map_path) then
    M.reload()
  end
end

return M
