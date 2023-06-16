local utils = require "nrepl.utils"
local bencode = require "nrepl.bencoded"
local luv = require "luv"

local namespace = vim.api.nvim_create_namespace "nrepl"

local nrepl = {}

-- The internal socet connection to the nrepl
nrepl.connection = nil

-- The log buffer where all the output will og
nrepl.buffer = nil

-- The session id on the nrepl
nrepl.session = nil

-- A map of points to locations where requests were made from so we know where
-- to put the results
nrepl.points = {}

---Logs a message to the the log buffer. If the ID is found in the points it
---will add the first line of output as virtual text on tat position
---@param id string | nil
---@param message string
local log = function(id, message)
  vim.schedule(function()
    local lines = vim.split(message, "\n")

    if id ~= nil and nrepl.points[id] ~= nil then
      local point = nrepl.points[id]
      vim.api.nvim_buf_set_extmark(0, namespace, point.line - 1, 0, {
        id = 1,
        virt_text = { { lines[1], "Comment" } },
      })
    end

    for _, value in ipairs(lines) do
      vim.api.nvim_buf_set_lines(nrepl.buffer, -1, -1, false, { value })
    end
  end)
end

---Send and "eval" operation to the nrepl via the current connection
---@param title string
---@param code string
local eval = function(title, code)
  if not nrepl.has_connection() then
    print "Nrepl not connected. Please run `NreplConnect`"
    return
  end

  local id = utils.uuid()
  local line, column = unpack(vim.api.nvim_win_get_cursor(0))

  -- Add the current point so we know where to print the result when the repl
  -- has finished
  nrepl.points[id] = { line = line, column = column }

  -- Print out a separator so we can see each result
  log(nil, ";; " .. string.rep("-", 100))
  log(nil, ";; eval " .. title)

  nrepl.connection:write(bencode.encode {
    id = id,
    -- ns = utils.get_namespace(),
    file = vim.fn.expand "%",
    session = nrepl.session,
    line = line,
    column = column,
    op = "eval",
    code = code,
  })
end

---Handles new in coming messages from the nrepl
---@param message table
local handel_message = function(message)
  if message["new-session"] then
    nrepl.session = message["new-session"]
  end

  -- You can uncomment this line to print all messages received from the repel
  -- into the log buffer
  -- log(nil, vim.inspect(message))

  local content = utils.get_message_content(message)
  if content ~= nil then
    log(message.id, content)
  end
end

---Tests to see if we have a current connection to the nrepl. If we don't all
---attempts to interact with it will fail
---@return boolean
nrepl.has_connection = function()
  return nrepl.connection ~= nil
end

---Disconnect from the nrepl and clean up all the connections and buffers
nrepl.disconnect = function()
  if not nrepl.has_connection() then
    return
  end

  nrepl.connection:shutdown()
  nrepl.connection:close()
  nrepl.connection = nil
  nrepl.session = nil
  -- TODO(AdeAttwood): Actually close the buffer
  nrepl.buffer = nil
end

---Creates a new connection to a running nrepl. Sets up all the log buffers and
---tpc socets
---@param host string
---@param port number
nrepl.connect = function(host, port)
  if nrepl.has_connection() then
    return
  end

  local buffer = vim.api.nvim_create_buf(true, true)
  vim.api.nvim_buf_set_option(buffer, "filetype", "clojure")
  vim.api.nvim_buf_set_var(buffer, "bufftype", "nofile")
  vim.api.nvim_buf_set_name(buffer, "ReplLog")

  nrepl.buffer = buffer

  nrepl.connection = luv.new_tcp()
  nrepl.connection:connect(host, port, function(connection_err)
    assert(not connection_err, connection_err)

    local chunk_buffer = ""
    nrepl.connection:read_start(function(read_err, chunk)
      assert(not read_err, read_err)

      if chunk then
        -- Add the current chunk to the chunk buffer.
        chunk_buffer = chunk_buffer .. chunk

        -- Try and decode what we have of the chunk_buffer. If we are able to
        -- decoded it we can remove what we have decode from the start of the
        -- chunk_buffer. If not then we are still waiting on some chunks to
        -- complete our message, if this happens we can skip this chunk and
        -- wait until all the chunks have been sent to us before continuing
        -- with the message.
        local message, index
        message, index = bencode.decode(chunk_buffer)
        while message do
          assert(type(index) == "number", "Index must be a number if data can be decoded")
          assert(type(message) == "table", "Invalid message expected a table")
          chunk_buffer = string.sub(chunk_buffer, index, -1)
          handel_message(message)

          message, index = bencode.decode(chunk_buffer)
        end
      else
        nrepl.disconnect()
      end
    end)

    -- Kick of the connection by creating a new session on the nrepl
    nrepl.connection:write(bencode.encode { op = "clone" })
  end)
end

---Evaluates the block at the cursor. This will use tree sitter to get the
---cloest parent list
nrepl.evaluate_at_cursor = function()
  if not nrepl.has_connection() then
    print "Nrepl not connected. Please run `NreplConnect`"
    return
  end

  local code = utils.get_list_at_cursor()
  local title = string.gsub(code, "\n", " ")
  eval(title, code)
end

---Evaluates all the code in the current buffer
nrepl.evaluate_at_buffer = function()
  if not nrepl.has_connection() then
    print "Nrepl not connected. Please run `NreplConnect`"
    return
  end

  local lines = vim.api.nvim_buf_get_lines(0, 0, -1, false)
  assert(type(lines) == "table", "Unable to get the lines of the current buffer")

  local title = vim.fn.expand "%"
  local code = table.concat(lines, "\n")
  eval(title, code)
end

return nrepl
