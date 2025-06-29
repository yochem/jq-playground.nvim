local M = {}

function M.setup(opts)
  local confmod = require("jq-playground.config")

  local cfg = vim.tbl_deep_extend("force", confmod.default_config, opts or {})

  vim.api.nvim_create_user_command("JqPlayground", function(params)
    require("jq-playground.playground").init_playground(params.fargs[1], cfg)
  end, {
    desc = "Start jq query editor and live preview",
    nargs = "?",
    complete = "file",
  })
end

return M
