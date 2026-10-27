-- Finds and reads .context-outline/root.json, and builds the copied context text.
local M = {}

M.MAP_REF = ".context-outline/root.json"

-- Walk up from `start` (default: cwd) to find the map.
-- Returns the project root dir and the map path, or nil.
function M.find(start)
  local found = vim.fs.find(M.MAP_REF, { upward = true, path = start or vim.fn.getcwd(), type = "file" })[1]
  if not found then
    return nil
  end
  return vim.fs.dirname(vim.fs.dirname(found)), found
end

-- Read and decode the map. Returns data or nil, err.
function M.load(path)
  local ok, lines = pcall(vim.fn.readfile, path)
  if not ok then
    return nil, "could not read " .. path
  end
  local text = table.concat(lines, "\n")
  if vim.trim(text) == "" then
    return nil, path .. " is empty"
  end
  local ok2, data = pcall(vim.json.decode, text, { luanil = { object = true, array = true } })
  if not ok2 or type(data) ~= "table" then
    return nil, "invalid JSON in " .. path .. ": " .. tostring(data)
  end
  return data
end

-- Parse "12-30" or "12" into 1-based start/end lines.
function M.parse_lines(lines)
  if lines == nil or lines == "" then
    return nil
  end
  local a, b = tostring(lines):match("^%s*(%d+)%s*%-?%s*(%d*)%s*$")
  a = tonumber(a)
  if not a then
    return nil
  end
  b = tonumber(b) or a
  return math.max(a, 1), math.max(b, a, 1)
end

function M.title(node)
  return node.title or node.name or "(untitled)"
end

-- context mapping from @.context-outline/root.json
-- item: "3. the title of the item"
function M.context_block(nodes)
  local out = { "context mapping from @" .. M.MAP_REF }
  for _, node in ipairs(nodes) do
    table.insert(out, string.format('item: "%s"', M.title(node)))
  end
  return table.concat(out, "\n") .. "\n"
end

return M
