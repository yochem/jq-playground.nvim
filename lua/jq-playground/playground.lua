local M = {}
local ns = vim.api.nvim_create_namespace("jq-playground")
local augroup = vim.api.nvim_create_augroup("jq-playground", {})

local function show_error(msg)
  vim.notify("jq-playground: " .. msg, vim.log.levels.ERROR, {})
end

local function user_preferred_indent(json_bufnr)
  local prefer_tabs = not vim.bo[json_bufnr].expandtab
  if prefer_tabs then
    return { "--tab" }
  end

  local indent_width = vim.bo[json_bufnr].tabstop
  if 0 < indent_width and indent_width < 8 then
    return { "--indent", indent_width }
  end

  return {}
end

-- TODO: refactor
local function run_query(cmd, input, query_bufnr, output_bufnr)
  local cli_args = vim.deepcopy(cmd)
  local filter_lines = vim.api.nvim_buf_get_lines(query_bufnr, 0, -1, false)
  local filter = table.concat(filter_lines, "\n")
  table.insert(cli_args, filter)
  vim.list_extend(cli_args, user_preferred_indent(output_bufnr))
  local stdin = nil

  if type(input) == "number" and vim.api.nvim_buf_is_valid(input) then
    local modified = vim.bo[input].modified
    local fname = vim.api.nvim_buf_get_name(input)

    if (not modified) and fname ~= "" then
      -- the following should be faster as it lets jq read the file contents
      table.insert(cli_args, fname)
    else
      stdin = vim.api.nvim_buf_get_lines(input, 0, -1, false)
    end
  elseif type(input) == "string" and vim.fn.filereadable(input) == 1 then
    table.insert(cli_args, input)
  else
    show_error("invalid input: " .. input)
  end

  local on_exit = function(result)
    vim.schedule(function()
      local out = result.code == 0 and result.stdout or result.stderr
      local lines = vim.split(out, "\n", { plain = true })
      vim.api.nvim_buf_set_lines(output_bufnr, 0, -1, false, lines)
    end)
  end

  local ok, _ = pcall(vim.system, cli_args, { stdin = stdin }, on_exit)

  if not ok then
    show_error(cli_args[1] .. " is not installed or not on your $PATH")
  end
end

local function resolve_winsize(num, max)
  if num == nil or (1 <= num and num <= max) then
    return num
  elseif 0 < num and num < 1 then
    return math.floor(num * max)
  else
    show_error(string.format("incorrect winsize, received %s of max %s", num, max))
  end
end

local function create_split_buf(opts)
  local bufnr = vim.fn.bufnr(opts.name)
  if bufnr == -1 then
    bufnr = vim.api.nvim_create_buf(true, opts.scratch)
    vim.bo[bufnr].filetype = opts.filetype
    vim.api.nvim_buf_set_name(bufnr, opts.name)
  end

  local height = resolve_winsize(opts.height, vim.api.nvim_win_get_height(0))
  local width = resolve_winsize(opts.width, vim.api.nvim_win_get_width(0))

  local winid = vim.api.nvim_open_win(bufnr, true, {
    split = opts.split_direction,
    width = width,
    height = height,
  })

  return bufnr, winid
end

local function set_config(config, filetype)
  if filetype == "json" then
    config.cmd = config.json_cmd
    config.output_window.filetype = config.output_window.json_filetype
    config.query_window.filetype = config.query_window.json_filetype
  elseif filetype == "yaml" then
    config.cmd = config.yaml_cmd
    config.output_window.filetype = config.output_window.yaml_filetype
    config.query_window.filetype = config.query_window.yaml_filetype
  end
  return config
end

function M.init_playground(filename)
  local config = require("jq-playground.config").config
  local input_bufnr = vim.api.nvim_get_current_buf()
  local filetype = vim.api.nvim_get_option_value("filetype", { buf = input_bufnr })
  if filetype ~= "json" and filetype ~= "yaml" then
    vim.ui.select({ "json", "yaml" }, {
      prompt = "Please select a filetype",
    }, function(type)
      config = set_config(config, type)
    end)
  else
    config = set_config(config, filetype)
  end

  local output_bufnr, _ = create_split_buf(config.output_window)
  local query_bufnr, _ = create_split_buf(config.query_window)

  vim.api.nvim_buf_set_lines(output_bufnr, 0, -1, false, {})

  vim.api.nvim_buf_set_extmark(query_bufnr, ns, 0, 0, {
    virt_text = { { "Run your query with <CR>.", "Conceal" } },
  })

  -- Delete hint about running the query as soon as the user does something
  vim.api.nvim_create_autocmd({ "TextChanged", "InsertEnter" }, {
    once = true,
    group = augroup,
    buffer = query_bufnr,
    callback = function()
      vim.api.nvim_buf_clear_namespace(query_bufnr, ns, 0, -1)
    end,
  })

  local run_query_with_file = function()
    run_query(config.cmd, filename or input_bufnr, query_bufnr, output_bufnr)
  end

  vim.keymap.set({ "n", "i" }, "<Plug>(JqPlaygroundRunQuery)", run_query_with_file, {
    buffer = query_bufnr,
    silent = true,
    desc = "JqPlaygroundRunQuery",
  })

  -- To have a sensible default. Does not require user to define one
  if not config.disable_default_keymap then
    vim.keymap.set({ "n" }, "<CR>", "<Plug>(JqPlaygroundRunQuery)", {
      desc = "Default for JqPlaygroundRunQuery",
    })
  end
end

return M
