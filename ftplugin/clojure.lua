local repl = require "nrepl.nrepl"
local utils = require "nrepl.utils"

vim.api.nvim_create_user_command("NreplConnect", function()
  local port = utils.get_port()
  if port then
    repl.connect("127.0.0.1", port)
  end
end, {})

vim.api.nvim_create_user_command("NreplDisconnect", function()
  repl.disconnect()
end, {})

vim.api.nvim_set_keymap("n", "<leader>ee", "", { nowait = true, silent = true, callback = repl.evaluate_at_cursor })
vim.api.nvim_set_keymap("n", "<leader>eb", "", { nowait = true, silent = true, callback = repl.evaluate_at_buffer })
