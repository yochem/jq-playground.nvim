local M = {}

local function show_error(msg)
  vim.notify("jq-playground: " .. msg, vim.log.levels.ERROR, {})
end

local function user_preferred_indent(json_bufnr)
  local prefer_tabs = not vim.bo[json_bufnr].expandtab
  if prefer_tabs then
    return { "--tab" }
  else
    local indent_width = vim.bo[json_bufnr].softtabstop
    return { "--indent", indent_width }
  end
end

-- TODO: refactor
local function run_query(input, query_bufnr, output_bufnr)
  local filter_lines = vim.api.nvim_buf_get_lines(query_bufnr, 0, -1, false)
  local filter = table.concat(filter_lines, "\n")
  local cmd = { "jq", filter }
  vim.list_extend(cmd, user_preferred_indent(output_bufnr))
  local stdin = nil

  if type(input) == "number" and vim.api.nvim_buf_is_valid(input) then
    local modified = vim.bo[input].modified
    local fname = vim.api.nvim_buf_get_name(input)

    if (not modified) and fname ~= "" then
      -- the following should be faster as it lets jq read the file contents
      table.insert(cmd, fname)
    else
      stdin = vim.api.nvim_buf_get_lines(input, 0, -1, false)
    end
  elseif type(input) == "string" and vim.fn.filereadable(input) == 1 then
    table.insert(cmd, input)
  else
    show_error("invalid input: " .. input)
  end
  local ok, process = pcall(vim.system, cmd, { stdin = stdin })

  if not ok then
    show_error("jq is not installed or not on your $PATH")
    return
  end

  local result = process:wait()
  local output = result.code == 0 and result.stdout or result.stderr

  local lines = vim.split(output, "\n", { plain = true })
  vim.api.nvim_buf_set_lines(output_bufnr, 0, -1, false, lines)
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

local function create_split_scratch_buf(bufopts, winopts)
  local bufnr = vim.api.nvim_create_buf(false, true)
  vim.bo[bufnr].filetype = bufopts.filetype
  vim.api.nvim_buf_set_name(bufnr, bufopts.name)

  local height = resolve_winsize(winopts.height, vim.api.nvim_win_get_height(0))
  local width = resolve_winsize(winopts.width, vim.api.nvim_win_get_width(0))

  local winid = vim.api.nvim_open_win(bufnr, true, {
    split = winopts.split_direction,
    width = width,
    height = height,
  })

  return bufnr, winid
end

local function init_playground(opts)
  local input_json_bufnr = vim.api.nvim_get_current_buf()

  local output_json_bufnr, _ = create_split_scratch_buf({
    name = "jq output",
    filetype = "json",
  }, opts.output_window)

  local query_bufnr, winid = create_split_scratch_buf({
    name = "jq query editor",
    filetype = "jq",
  }, opts.query_window)

  vim.api.nvim_buf_set_lines(query_bufnr, 0, -1, false, {
    "# JQ filter: press set keymap (default <CR> in normal mode) to execute.",
    "",
    "",
  })
  vim.api.nvim_win_set_cursor(winid, { 3, 0 })
  vim.cmd.startinsert()

  local run_jq_query = function()
    run_query(opts.filename or input_json_bufnr, query_bufnr, output_json_bufnr)
  end
  local run_jq_query_opts = {
    buffer = query_bufnr,
    silent = true,
    desc = "Run current jq query",
  }
  for _, mapping in ipairs(opts.query_keymaps) do
    vim.keymap.set(mapping[1], mapping[2], run_jq_query, run_jq_query_opts)
  end
end

function M.setup(opts)
  local defaults = {
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
    query_keymaps = {
      { "n", "<CR>" },
    },
  }

  local options = vim.tbl_deep_extend("force", defaults, opts)

  vim.api.nvim_create_user_command("JqPlayground", function(params)
    options["filename"] = params.fargs[1]
    init_playground(options)
  end, {
    desc = "Start jq query editor and live preview",
    nargs = "?",
    complete = "file",
  })
end

return M
