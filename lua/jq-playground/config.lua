local M = {}

M.default_config = {
  json_cmd = { "jq" },
  yaml_cmd = { "yq" },
  output_window = {
    split_direction = "right",
    width = nil,
    height = nil,
    scratch = true,
    json_filetype = "json",
    yaml_filetype = "yaml",
    name = "output",
  },
  query_window = {
    split_direction = "below",
    width = nil,
    height = 0.3,
    scratch = false,
    json_filetype = "jq",
    yaml_filetype = "yq",
    name = "query editor",
  },
  disable_default_keymap = false,
}

M.config = vim.deepcopy(M.default_config, false)

return M
