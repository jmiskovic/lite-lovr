local lovr = { thread     = require 'lovr.thread',
               timer      = require 'lovr.timer',
               data       = require 'lovr.data',
               filesystem = require 'lovr.filesystem' }

local generalchannel, eventschannel, renderchannel, threadname

-- lite expects these to be defined as global
_G.ARGS = {}
_G.SCALE = 1
_G.PATHSEP = package.config:sub(1, 1)

-- serialization
local serpent = require'serpent'

local serialize = function(...)
  return serpent.line({...}, {comment=false})
end


local deserialize = function(line)
  local ok, res = serpent.load(line)
  assert(ok, 'invalid loading of string "' .. line .. '"')
  return res
end


-- monkey-patching needed to prepare lua 5.1 environment for lite editor
table.unpack = unpack -- lua 5.2 feature

function io.open(path, mode) -- routing file IO through lovr.filesystem
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
        lovr.filesystem.write(self.path, self.towrite)
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
    renderer.frame = {}
    table.insert(renderer.frame, {'begin_frame'})
  end,

  end_frame = function()
    table.insert(renderer.frame, {'end_frame'})
    renderchannel:push(serpent.line(renderer.frame, {comment=false}))
  end,

  set_litecolor = function(color)
    local r, g, b, a = 255, 255, 255, 255
    if color and #color >= 3 then r, g, b = unpack(color, 1, 3) end
    if #color >= 4 then a = color[4] end
    r, g, b, a = r / 255, g / 255, b / 255, a / 255
    table.insert(renderer.frame, {'set_litecolor', r, g, b, a})
  end,

  set_clip_rect = function(x, y, w, h)
    table.insert(renderer.frame, {'set_clip_rect', x, y, w, h})
  end,

  draw_rect = function(x, y, w, h, color)
    renderer.set_litecolor(color)
    table.insert(renderer.frame, {'draw_rect', x, y, w, h})
  end,

  draw_text = function(font, text, x, y, color)
    renderer.set_litecolor(color)
    table.insert(renderer.frame, {'draw_text', text, x, y, font.filename, font.size})
    local width = font:get_width(text)
    return x + width
  end,

  font = {
    load = function(filename, size)
      -- table.insert(renderer.frame, {'font_load', filename, size})
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


-- receive key events from main thread and  sys queries
_G.system = {
  infocus = false,
  event_queue = {},
  clipboard = '',

  poll_event = function()
    local event = eventschannel:pop(false)
    if not event then
      return nil
    end
    local deserialized = deserialize(event)
    if deserialized[1] == 'set_focus' then
      system.infocus = deserialized[2] or false
      return system.poll_event()
    elseif deserialized[1] == 'resize' then
      renderer.size = { deserialized[2], deserialized[3] }
      return system.poll_event()
    end     
    if system.infocus then
      return unpack(deserialized)
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
generalchannel = lovr.thread.getChannel('lite-editors')
eventname, threadname = unpack(deserialize(generalchannel:pop(true)))
assert(eventname == 'new_thread')
eventschannel = lovr.thread.getChannel(string.format('%s-events', threadname))
renderchannel = lovr.thread.getChannel(string.format('%s-render', threadname))

-- the lua env is now ready for executing lite
local lite = require 'core'

lite.init()
lite.run()  -- blocks in infinite loop
