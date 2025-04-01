local M = {}

M.default_config = {
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

M.config = vim.deepcopy(M.default_config, false)

return M
