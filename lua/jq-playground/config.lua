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
    name = "query editor",
  },
  disable_default_keymap = false,
}

return M
