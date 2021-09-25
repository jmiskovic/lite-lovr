table.unpack = unpack -- lua 5.2 feature missing from 5.1

-- lite expects these to be defined as global
ARGS = {}
SCALE = 1
PATHSEP = package.config:sub(1, 1)

renderer = {
  show_debug = function(show)
      print('show_debug', show)
  end,

  get_size = function()
      return 1000, 1000
  end,

  begin_frame = function()
    lovr.graphics.setDepthTest('lequal', false)
  end,

  end_frame = function()
    lovr.graphics.setDepthTest('lequal', true)
    lovr.graphics.setStencilTest()
  end,

  set_clip_rect = function(x, y, w, h)
    --[[
    lovr.graphics.stencil(
      function() lovr.graphics.plane("fill", x + w/2, -y - h/2, 0, w, h) end,
      'replace',
      200,
      0)
    lovr.graphics.setStencilTest('greater', 100)
    --]]
  end,

  set_litecolor = function(color)
    local r, g, b, a = 255, 255, 255, 255
    if color and #color >= 3 then r, g, b = unpack(color, 1, 3) end
    if #color >= 4 then a = color[4] end
    lovr.graphics.setColor(r / 255, g / 255, b / 255, a / 255)
  end,

  draw_rect = function(x, y, w, h, color)
    renderer.set_litecolor(color)
    lovr.graphics.plane("fill", x + w/2, -y - h/2, 0, w, h)
  end,

  draw_text = function(font, text, x, y, color)
    renderer.set_litecolor(color)
    lovr.graphics.setFont(font.font)
    lovr.graphics.print(text, x, -y, 0, 1, 0, 0,1,0, nil, 'left', 'top')
    return x + font.font:getWidth(text)
  end,

  font = {
    load = function(filename, size)
      local font = lovr.graphics.newFont(filename, size)
      font:setPixelDensity(1)
      return {
        font = font,
        size = size,
        set_tab_width = function(self, n)
        end,
        get_width = function(self, text)
          return self.font:getWidth(text)
        end,
        get_height = function(self)
          return self.font:getHeight()
        end
      }
    end
  }
}

system = {
  event_queue = {},
  clipboard = '',

  poll_event = function()
    local liteev = table.remove(system.event_queue, 1)
    if liteev then
        return unpack(liteev)
    end
  end,

  wait_event = function(n)
    print('system.wait_event', n)
    return false
  end,

  set_cursor = function(cursor)
    print('system.set_cursor', cursor)
  end,

  set_window_title = function(title)
    print('system.set_window_title', title)
  end,

  set_window_mode = function(mode)
    print('system.set_window_mode', mode)
  end,

  window_has_focus = function()
    --print('system.window_has_focus')
    return true
  end,

  show_confirm_dialog = function(title, msg)
    print('system.show_confirm_dialog', title, msg)
  end,

  chdir = function(dir)
    print('system.chdir', dir)
  end,

  list_dir = function(path)
    if path == '.' then
      path = ''
    end
    return lovr.filesystem.getDirectoryItems(path)
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

  exec = function(cmd)
    print('system.exec', cmd)
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
}

-- monkey-patching io.open() to route IO through lovr.filesystem
function io.open(path, mode)
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


local lite = require 'core'

function lovr.load(...)
  ARGS = ...
  table.insert(ARGS, 1, ARGS[0])
  table.insert(ARGS, 1, ARGS['exe'])
  lite.init()
end


function lovr.draw()
  lite.redraw = true
  lite.frame_start = lovr.timer.getTime()
  lovr.graphics.push()
  lovr.graphics.translate(0,2,-1)
  lovr.graphics.scale(1 / renderer.get_size())

  lite.run_frame()
  lovr.graphics.pop()
end


-- keyboard handling

local function expand_keyname(key)
  if key:sub(1, 2) == "kp" then
    return "keypad " .. key:sub(3)
  end
  if key:sub(2) == "ctrl" or key:sub(2) == "shift" or key:sub(2) == "alt" or key:sub(2) == "gui" then
    if key:sub(1, 1) == "l" then return "left " .. key:sub(2) end
    return "right " .. key:sub(2)
  end
  return key
end


lovr.keypressed = function(key, scancode, rpt)
  table.insert(system.event_queue, {'keypressed', expand_keyname(key)})
end


lovr.keyreleased = function(key, scancode)
  table.insert(system.event_queue, {'keyreleased', expand_keyname(key)})
end


lovr.textinput = function(text, code)
  table.insert(system.event_queue, {'textinput', text})
end
