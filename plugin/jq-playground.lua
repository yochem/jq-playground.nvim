if vim.g.loaded_jq_playground ~= nil then
  return
end
vim.g.loaded_jq_playground = true

if vim.version.lt(vim.version(), '0.10') then
  local msg = string.format(
    'jq-playground requires Nvim v0.10+, you have Nvim v%s',
    tostring(vim.version())
  )
  vim.notify_once(msg, vim.log.levels.WARN, {})
  return
end

require("jq-playground").setup()
