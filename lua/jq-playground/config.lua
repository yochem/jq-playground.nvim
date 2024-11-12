local M = {}

M.default_config = {
  output_window = {
    split_direction = "right",
    width = nil,
    height = nil,
  },
  query_window = {
    split_direction = "below",
    width = nil,
    height = 0.3,
  },
  disable_default_keymap = false,
}

M.config = vim.deepcopy(M.default_config, false)

return M
