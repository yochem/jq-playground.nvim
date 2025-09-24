if vim.g.loaded_jq_playground ~= nil then
  return
end
vim.g.loaded_jq_playground = true

require("jq-playground").setup()
