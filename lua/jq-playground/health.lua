local M = {}

local function jq_found()
  vim.health.start("Dependency: jq")
  local ok, process = pcall(vim.system, { 'jq', '--version' }, {})

  if not ok then
    vim.health.error("jq is not installed or not on your $PATH")
  else
    local result = process:wait()
    local version = result.stdout
    if version ~= nil then
      vim.health.ok(vim.trim(version) .. " is installed")
    else
      vim.health.error("jq is not installed or not on your $PATH")
    end
  end
end

local function configuration()
  vim.health.start("Configuration")
  local confmod = require("jq-playground.config")

  if vim.deep_equal(confmod.config, confmod.default_config) then
    vim.health.ok("using default configuration")
  end

  if confmod.config.query_keymaps ~= nil then
    vim.health.warn("query_keymaps in config is deprecated. Use <Plug>(JqPlaygroundRunQuery)")
  end

  vim.health.info("Configuration:\n" .. vim.inspect(confmod.config))
end

M.check = function()
  jq_found()
  configuration()
end

return M
