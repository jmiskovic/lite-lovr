local serpent = require'serpent'

local lovr = { thread     = require 'lovr.thread',
               timer      = require 'lovr.timer',
               data       = require 'lovr.data',
               filesystem = require 'lovr.filesystem' }

local lite_editors_channel, inbound_channel, outbound_channel, threadname
local lite_core, lite_command

-- lite expects these to be defined as global
_G.ARGS = {}
_G.SCALE = 1
_G.EXEDIR = ""
_G.PATHSEP = package.config:sub(1, 1)


local serialize = function(...)
  return serpent.line({...}, {comment=false})
end


local deserialize = function(line)
  local ok, res = serpent.load(line)
  assert(ok, 'invalid loading of string "' .. line .. '"')
  return res
end


table.unpack = unpack -- monkey-patching a lua 5.2 feature into lua 5.1 (used by lite)


function io.open(path, mode) -- routing file IO through lovr.filesystem
  if not mode:find('w') and not lovr.filesystem.isFile(path) then
    return false, path .. ": No such file or directory"
  end
  return {
    path = path,
    towrite = '',
    write = function(self, text)
      self.towrite = self.towrite .. text
    end,
    read = function(self, mode)
      return lovr.filesystem.read(self.path or '') or ''
    end,
    lines = function(self)
      local content = lovr.filesystem.read(self.path)
      local position = 1
      local function next()
        if position > #content then
          return nil
        end
        local nextpos = string.find(content, '\n', position, true)
        local line
        if nextpos == nil then
          line = content:sub(position, #content)
          position = #content
        else
          line = content:sub(position, nextpos - 1)
          position = nextpos + 1
        end
        return line
      end
      return next
    end,
    close = function(self)
      if self.towrite ~= '' then
        -- TODO: check that path exists, create any missing dirs
        local bytes = lovr.filesystem.write(self.path, self.towrite)
        if bytes == 0 then
          error('Could not save to ' .. path, 0)
        end
      end
    end
  }
end


-- renderer collects draw calls and sends whole frame to the main thread
_G.renderer = {
  frame = {},
  size = {1000, 1000},

  get_size = function()
      return renderer.size[1], renderer.size[2]
  end,

  begin_frame = function()
    renderer.add_event('begin_frame')
  end,

  end_frame = function()
    renderer.add_event('end_frame')
    outbound_channel:push(serpent.line(renderer.frame, {comment=false}))
    renderer.frame = {}
  end,

  set_litecolor = function(color)
    local r, g, b, a = 255, 255, 255, 255
    if color and #color >= 3 then r, g, b = unpack(color, 1, 3) end
    if #color >= 4 then a = color[4] end
    r, g, b, a = r / 255, g / 255, b / 255, a / 255
    renderer.add_event('set_litecolor', r, g, b, a)
  end,

  set_clip_rect = function(x, y, w, h)
    renderer.add_event('set_clip_rect', x, y, w, h)
  end,

  draw_rect = function(x, y, w, h, color)
    renderer.set_litecolor(color)
    renderer.add_event('draw_rect', x, y, w, h)
  end,

  draw_text = function(font, text, x, y, color)
    renderer.set_litecolor(color)
    renderer.add_event('draw_text', text, x, y, font.filename, font.size)
    local width = font:get_width(text)
    return x + width
  end,

  font = {
    load = function(filename, size)
      return {
        filename = filename,
        size = size,
        rasterizer = lovr.data.newRasterizer(filename, size),
        set_tab_width = function(self, n) end,
        get_width = function(self, text)
          local width = self.rasterizer:getWidth(text)
          return width
        end,
        get_height = function(self)
          local height = self.rasterizer:getHeight()
          return height
        end
      }
    end
  }
}


local litelovr_handlers = {
  set_focus = function(infocus)
    system.infocus = infocus or false
  end,

  resize = function(width, height)
    renderer.size = { width, height }
  end,

  lovr_error_message = function(message, traceback)
    lite_core.log_quiet('%s\n%s', message, traceback)
    lite_command.perform("core:open-log")
  end,
}


function _G.renderer.add_event(...)
  table.insert(_G.renderer.frame, {...})
end


function _G.renderer.register_plugin(name, mainthread_callbacks, thread_callbacks)
  table.insert(_G.renderer.frame, {'register_plugin', name, mainthread_callbacks})
  for event, handler_fn in pairs(thread_callbacks or {}) do
    litelovr_handlers[event] = handler_fn
  end
end


-- receive events from host, handle system queries
_G.system = {
  threadname = '',
  infocus = false,
  event_queue = {},
  clipboard = '',

  poll_event = function()
    local event_str = inbound_channel:pop(false)
    if not event_str then
      return nil
    end
    local event = deserialize(event_str)
    if litelovr_handlers[event[1]] then
      litelovr_handlers[event[1]](select(2, unpack(event)))
      return system.poll_event()
    elseif system.infocus then
      return unpack(event)
    end
  end,

  wait_event = function(timeout)
    lovr.timer.sleep(timeout)
  end,

  absolute_path = function(filename)
    return string.format('%s%s%s', lovr.filesystem.getRealDirectory(filename) or '', PATHSEP, filename)
  end,

  get_file_info = function(path)
    local type
    if path and lovr.filesystem.isFile(path) then
      type = 'file'
    elseif path and path ~= "" and lovr.filesystem.isDirectory(path) then
      type = 'dir'
    else
      return nil, "Doesn't exist"
    end
    return {
      modified = lovr.filesystem.getLastModified(path),
      size = lovr.filesystem.getSize(path),
      type = type
    }
  end,

  get_clipboard = function()
    return system.clipboard
  end,

  set_clipboard = function(text)
    system.clipboard = text
  end,

  get_time = function()
    return lovr.timer.getTime()
  end,

  sleep = function(s)
    lovr.timer.sleep(s)
  end,

  list_dir = function(path)
    if path == '.' then
      path = ''
    end
    return lovr.filesystem.getDirectoryItems(path)
  end,

  fuzzy_match = function(str, ptn)
    local istr = 1
    local iptn = 1
    local score = 0
    local run = 0
    while istr <= str:len() and iptn <= ptn:len() do
      while str:sub(istr,istr) == ' ' do istr = istr + 1 end
      while ptn:sub(iptn,iptn) == ' ' do iptn = iptn + 1 end
      local cstr = str:sub(istr,istr)
      local cptn = ptn:sub(iptn,iptn)
      if cstr:lower() == cptn:lower() then
        score = score + (run * 10)
        if cstr ~= cptn then score = score - 1 end
        run = run + 1
        iptn = iptn + 1
      else
        score = score - 10
        run = 0
      end
      istr = istr + 1
    end
    if iptn > ptn:len() then
      return score - str:len() - istr + 1
    end
  end,

  window_has_focus = function()
    return system.infocus
  end,

  -- no-ops and stubs

  set_cursor = function(cursor) end,

  set_window_title = function(title) end,

  set_window_mode = function(mode) end,

  chdir = function(dir) end,

  -- used when dir is dropped onto lite window, to open it in another process
  exec = function(cmd) end,

  show_confirm_dialog = function(title, msg)
    return true -- this one is unfortunate: on quit all changes will be unsaved
  end,
}

-- find out own name and open up channels to main thread
local eventname
lite_editors_channel = lovr.thread.getChannel('lite-editors')
eventname, threadname = unpack(deserialize(lite_editors_channel:pop(true)))
assert(eventname == 'new_thread')
inbound_channel = lovr.thread.getChannel(string.format('%s-events', threadname))
outbound_channel = lovr.thread.getChannel(string.format('%s-render', threadname))
system.threadname = threadname

-- the lua env is now ready for executing lite

lite_core = require 'core'
lite_command = require 'core/command'

lite_core.init()
lite_core.run()  -- blocks in infinite loop
