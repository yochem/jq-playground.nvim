local M = {}
local ns = vim.api.nvim_create_namespace("jq-playground")
local augroup = vim.api.nvim_create_augroup("jq-playground", {})

---@param msg string
local function show_error(msg)
  vim.notify("jq-playground: " .. msg, vim.log.levels.ERROR, {})
end

---@param cmd string
---@param query string
---@param flags string[]
---@param input string?
local function log_cmd(cmd, query, flags, input)
  local out = {
    when = os.time(),
    cmd = cmd,
    query = query,
    flags = flags,
    input = input or vim.NIL,
  }

  local histfile = vim.fs.joinpath(vim.fn.stdpath('log'), 'jq-playground-history.json')
  local fd = vim.uv.fs_open(histfile, 'a', tonumber('644', 8))
  if fd then
    local line = vim.json.encode(out)
    vim.uv.fs_write(fd, line .. '\n', -1)
    vim.uv.fs_close(fd)
  end
end

---Convert 'expandtab' and 'tabstop' to jq flags.
---@param buf integer
---@return string[]
local function user_preferred_indent(buf)
  local prefer_tabs = not vim.bo[buf].expandtab
  if prefer_tabs then
    return { "--tab" }
  end

  local indent_width = vim.bo[buf].tabstop
  if 0 < indent_width and indent_width < 8 then
    return { "--indent", tostring(indent_width) }
  end

  return {}
end

---Convert the input to jq arguments. If the buffer has a name, provide it as
---file argument. Otherwise the contents as stdin.
---@param source string|integer
---@return string?
---@return string[]?
local function input_args(source)
  if type(source) == "string" and vim.fn.filereadable(source) == 1 then
    return source, nil
  end

  if type(source) == "number" and vim.api.nvim_buf_is_valid(source) then
    local modified = vim.bo[source].modified
    local fname = vim.api.nvim_buf_get_name(source)

    if (not modified) and fname ~= "" then
      -- the following should be faster as it lets jq read the file contents
      return fname, nil
    else
      return nil, vim.api.nvim_buf_get_lines(source, 0, -1, false)
    end
  end

  show_error("invalid input: " .. source)
end

---@param cmd string[]
---@param input string|integer
---@param query_buf integer
---@param output_buf integer
local function run_query(cmd, input, query_buf, output_buf)
  local cli_args = vim.deepcopy(cmd)

  local filter_lines = vim.api.nvim_buf_get_lines(query_buf, 0, -1, false)
  local filter = table.concat(filter_lines, "\n")
  table.insert(cli_args, filter)

  local indent = user_preferred_indent(output_buf)
  vim.list_extend(cli_args, indent)

  local input_filename, stdin = input_args(input)
  if input_filename then
    table.insert(cli_args, input_filename)
  end

  local on_exit = vim.schedule_wrap(function(result)
    local out = result.code == 0 and result.stdout or result.stderr
    local lines = vim.split(out, "\n", { plain = true })
    vim.api.nvim_buf_set_lines(output_buf, 0, -1, false, lines)
  end)

  local ok = pcall(vim.system, cli_args, { stdin = stdin }, on_exit)
  if not ok then
    show_error(("%s is not installed or not on your $PATH"):format(cli_args[1]))
    return
  end
  log_cmd(cmd[1], filter, indent, input_filename)
end

---Convert relative window size to absolute. Nil is ignored.
---@param num number
---@param max integer
---@return integer?
local function resolve_winsize(num, max)
  if num == nil then
    return nil
  elseif 1 <= num and num <= max then
    return math.floor(num)
  elseif 0 < num and num < 1 then
    return math.floor(num * max)
  else
    show_error(string.format("incorrect winsize, received %s of max %s", num, max))
  end
end

---Creates a split buffer. Returns bufnr and winid
---@param opts table fields: name, scratch, filetype, height, width
---@return integer bufnr of the created buffer
---@return integer winid of the opened window
local function create_split_buf(opts)
  local buf = vim.fn.bufnr(opts.name)
  if buf == -1 then
    buf = vim.api.nvim_create_buf(true, opts.scratch)
    vim.bo[buf].filetype = opts.filetype
    vim.api.nvim_buf_set_name(buf, opts.name)
  end

  local height = resolve_winsize(opts.height, vim.api.nvim_win_get_height(0))
  local width = resolve_winsize(opts.width, vim.api.nvim_win_get_width(0))

  local winid = vim.api.nvim_open_win(buf, true, {
    split = opts.split_direction,
    width = width,
    height = height,
  })

  return buf, winid
end

---Place a hint in a buffer, deleted on InsertEnter and TextChanged
---@param buf integer
---@param hint string
local function virt_text_hint(buf, hint)
  vim.api.nvim_buf_set_extmark(buf, ns, 0, 0, {
    virt_text = { { hint, "Conceal" } },
  })

  -- Delete hint about running the query as soon as the user does something
  vim.api.nvim_create_autocmd({ "TextChanged", "InsertEnter" }, {
    once = true,
    group = augroup,
    buffer = buf,
    callback = function()
      vim.api.nvim_buf_clear_namespace(buf, ns, 0, -1)
    end,
  })
end

---@param filename string
function M.init_playground(filename)
  local cfg = require('jq-playground.config').config

  -- check if we're working with YAML
  local curbuf = vim.api.nvim_get_current_buf()
  local match_args = filename and { filename = filename } or { buf = curbuf }
  if vim.filetype.match(match_args) == "yaml" then
    cfg.cmd = { "yq" }
    cfg.output_window.filetype = "yaml"
    cfg.output_window.name = "yq output"
    cfg.query_window.filetype = "yq"
  end

  -- Create output buffer first
  local output_buf, _ = create_split_buf(cfg.output_window)
  vim.api.nvim_buf_set_lines(output_buf, 0, -1, false, {})

  -- And then query buffer
  local query_buf, _ = create_split_buf(cfg.query_window)
  virt_text_hint(query_buf, "Press enter to run the query…")

  vim.keymap.set({ "n", "i" }, "<Plug>(JqPlaygroundRunQuery)", function()
    run_query(cfg.cmd, filename or curbuf, query_buf, output_buf)
  end, {
    buffer = query_buf,
    silent = true,
    desc = "JqPlaygroundRunQuery",
  })

  -- To have a sensible default. Does not require user to define one
  if not cfg.disable_default_keymap then
    vim.keymap.set({ "n" }, "<CR>", "<Plug>(JqPlaygroundRunQuery)", {
      desc = "Default for JqPlaygroundRunQuery",
    })
  end
end

return M
