local M = {}

local function jq_found()
  vim.health.start("jq CLI")
  local conf = vim.deepcopy(require("jq-playground.config").config)
  table.insert(conf.cmd, "--version")
  local ok, process = pcall(vim.system, conf.cmd, {})

  local not_installed_msg = ("%s is not installed or not on your $PATH"):format(conf.cmd[1])
  if not ok then
    vim.health.error(not_installed_msg)
  else
    local result = process:wait()
    local version = result.stdout
    if version ~= nil then
      vim.health.ok(vim.trim(version) .. " is installed")
    else
      vim.health.error(not_installed_msg)
    end
  end
end

local function configuration()
  vim.health.start("Configuration")
  local confmod = require("jq-playground.config")

  if vim.deep_equal(confmod.config, confmod.default_config) then
    vim.health.ok("using default configuration")
  else
    vim.health.info("Custom configuration:\n" .. vim.inspect(confmod.config))
  end

  if confmod.config.query_keymaps ~= nil then
    vim.health.warn("query_keymaps in config is deprecated. Use <Plug>(JqPlaygroundRunQuery)")
  end
end

local function keymaps()
  vim.health.start("Keymaps")
  local found = false
  -- TODO: https://github.com/neovim/neovim/pull/29464 wait till merged
  local maps = vim.deepcopy(vim.api.nvim_get_keymap("n"))
  vim.list_extend(maps, vim.api.nvim_get_keymap("i"))
  for _, map in ipairs(maps) do
    if map.rhs and string.match(map.rhs, "JqPlayground") then
      vim.health.ok(("%s %s %s"):format(map.mode, map.lhs, map.rhs))
      found = true
    end
  end
  if not found then
    vim.health.info("No custom keymaps found")
  end
end

M.check = function()
  jq_found()
  configuration()
  keymaps()
end

return M
