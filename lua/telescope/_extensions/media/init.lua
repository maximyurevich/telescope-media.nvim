local present, telescope = pcall(require, "telescope")

if not present then
  vim.api.nvim_notify("This plugin requires telescope.nvim!", vim.log.levels.ERROR, {
    title = "telescope-media.nvim",
    prompt_title = "telescope-media.nvim",
    icon = " ",
  })
  return
end

local actions = require("telescope.actions")
local finders = require("telescope.finders")
local pickers = require("telescope.pickers")
local config = require("telescope.config")

local action_state = require("telescope.actions.state")
local make_entry = require("telescope.make_entry")

local canned = require("telescope._extensions.media.canned")
local media_previewer = require("telescope._extensions.media.preview")

local if_nil = vim.F.if_nil
local V = vim.fn

local _TelescopeMediaConfig = {
  backend = "none",
  move = false,
  on_confirm = canned.single.copy_path,
  on_confirm_muliple = canned.multiple.bulk_copy,
  cache_path = "/tmp/tele.media.cache",
  preview_title = "",
  results_title = "",
  prompt_title = "Media",
  cwd = vim.loop.cwd(),
  preview = {
    timeout = 200,
    redraw = false,
    wait = 10,
    fill = {
      mime = "",
      permission = "╱",
      binary = "X",
      file = "~",
      error = ":",
      timeout = "+",
    },
  },
}

local function _find_command(options)
  if options.find_command then
    if type(options.find_command) == "function" then return options.find_command(options) end
    return options.find_command
  elseif 1 == V.executable("rg") then
    return { "rg", "--files", "--color", "never" }
  elseif 1 == V.executable("fd") then
    return { "fd", "--type", "f", "--color", "never" }
  elseif 1 == V.executable("fdfind") then
    return { "fdfind", "--type", "f", "--color", "never" }
  elseif 1 == V.executable("find") then
    return { "find", ".", "-type", "f" }
  elseif 1 == V.executable("where") then
    return { "where", "/r", ".", "*" }
  end
  error("Invalid command!", vim.log.levels.ERROR)
end

local function _setup(options)
  options = if_nil(options, {})
  options.find_command = _find_command(options)
  _TelescopeMediaConfig = vim.tbl_deep_extend("keep", options, _TelescopeMediaConfig)
end

local function _media(options)
  options = if_nil(options, {})
  options.attach_mappings = if_nil(options.attach_mappings, function()
    actions.select_default:replace(function(prompt_buffer)
      local current_picker = action_state.get_current_picker(prompt_buffer)
      local selections = current_picker:get_multi_selection()

      actions.close(prompt_buffer)
      if #selections < 2 then
        options.on_confirm(action_state.get_selected_entry())
      else
        selections = vim.tbl_map(function(item) return item[1] end, selections)
        options.on_confirm_muliple(selections)
      end
    end)
    return true
  end)

  options = vim.tbl_deep_extend("keep", options, _TelescopeMediaConfig)

  local command = options.find_command[1]
  if options.search_dirs then
    for key, value in pairs(options.search_dirs) do
      options.search_dirs[key] = V.expand(value)
    end
  end

  if command == "fd" or command == "fdfind" or command == "rg" then
    if options.hidden then options.find_command[#options.find_command + 1] = "--hidden" end
    if options.no_ignore then options.find_command[#options.find_command + 1] = "--no-ignore" end
    if options.no_ignore_parent then options.find_command[#options.find_command + 1] = "--no-ignore-parent" end
    if options.follow then options.find_command[#options.find_command + 1] = "-L" end
    if options.search_file then
      if command == "rg" then
        options.find_command[#options.find_command + 1] = "-g"
        options.find_command[#options.find_command + 1] = "*" .. options.search_file .. "*"
      else
        options.find_command[#options.find_command + 1] = options.search_file
      end
    end
    if options.search_dirs then
      if command ~= "rg" and not options.search_file then options.find_command[#options.find_command + 1] = "." end
      vim.list_extend(options.find_command, options.search_dirs)
    end
  elseif command == "find" then
    if not options.hidden then
      table.insert(options.find_command, { "-not", "-path", "*/.*" })
      options.find_command = vim.tbl_flatten(options.find_command)
    end
    if options.no_ignore ~= nil then
      vim.notify("The 'no_ignore' key is not available for the 'find' command in 'find_files'.")
    end
    if options.no_ignore_parent ~= nil then
      vim.notify("The 'no_ignore_parent' key is not available for the 'find' command in 'find_files'.")
    end
    if options.follow then table.insert(options.find_command, 2, "-L") end
    if options.search_file then
      table.insert(options.find_command, "-name")
      table.insert(options.find_command, "*" .. options.search_file .. "*")
    end
    if options.search_dirs then
      table.remove(options.find_command, 2)
      for _, value in pairs(options.search_dirs) do
        table.insert(options.find_command, 2, value)
      end
    end
  end

  local popup_options = {}
  function options.get_preview_window() return popup_options.preview end

  options.entry_maker = make_entry.gen_from_file(options) -- support devicons

  local picker = pickers.new(options, {
    prompt_title = "Media",
    finder = finders.new_oneshot_job(options.find_command, options),
    previewer = media_previewer.new(options),
    sorter = config.values.file_sorter(options),
  })

  local line_count = vim.o.lines - vim.o.cmdheight
  if vim.o.laststatus ~= 0 then line_count = line_count - 1 end

  popup_options = picker:get_window_options(vim.o.columns, line_count)
  picker:find()
end

-- TODO: Add presets like image_media, font_media, audio_media, etc.
return telescope.register_extension({
  setup = _setup,
  exports = {
    media = _media,
  },
})
