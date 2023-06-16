local ts_utils = require "nvim-treesitter.ts_utils"

local utils = {}

---Create a new uuid v4
---@return string, number
utils.uuid = function()
  local template = "xxxxxxxx-xxxx-4xxx-yxxx-xxxxxxxxxxxx"
  return string.gsub(template, "[xy]", function(c)
    local v = (c == "x") and math.random(0, 0xf) or math.random(8, 0xb)
    return string.format("%x", v)
  end)
end

---Tries to get the text to display in the buffer from a message received from
---the nrepl. This can be the evaluation result or an error.
---@param message table
---@return string | nil
utils.get_message_content = function(message)
  if message.value then
    return message.value
  end

  if message.err then
    return message.err
  end

  if message.ex then
    return message.ex
  end

  return nil
end

---Get the port the current nrepl is listening on. This will be found the the
---`.nrepl-port` file in the current working directory. This will be created
---when an nrepl server is started for the current project.
---@return string | nil
utils.get_port = function()
  local handle = io.popen [[cat .nrepl-port]]
  if not handle then
    return nil
  end

  local port = handle:read "*a"
  handle:close()

  -- Then that the string is not empty and a valid port number. If we return an
  -- empty string this check will need to be done all over the app.
  if port == "" then
    return nil
  end

  return port
end

---Get the code content of the list at the current cursor position
---@return string
utils.get_list_at_cursor = function()
  local node = ts_utils.get_node_at_cursor()
  while node do
    if node:type() == "list_lit" then
      return vim.treesitter.get_node_text(node, 0)
    end

    node = node:parent()
  end
end

utils.get_namespace = function()
  local cursor_node = ts_utils.get_node_at_cursor()
  if cursor_node == nil then
    return "user"
  end

  local root = ts_utils.get_root_for_node(cursor_node)
  local namespace_query = vim.treesitter.query.parse(
    "clojure",
    [[(list_lit value: (((sym_lit) @name)
                  ((sym_lit) @value)
                  (#eq? @name "ns")))]]
  )

  local _, match = namespace_query:iter_matches(root, 0)()
  if match then
    return vim.treesitter.get_node_text(match[2], 0)
  end

  return "user"
end

return utils
