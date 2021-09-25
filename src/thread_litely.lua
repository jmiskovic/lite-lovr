require 'lovr.filesystem'
local lovr = { thread = require 'lovr.thread' }

local generalchannel = lovr.thread.getChannel('lite-editors')
local threadname = generalchannel:pop(true)

print('my name')

-- monkey-patching stuff
table.unpack = unpack -- lua 5.2 feature missing from 5.1

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
        print(position, #content, nextpos)
        local line
        if nextpos == nil then
          line = content:sub(position, #content)
          position = #content
          print('not found')
        else
          line = content:sub(position, nextpos - 1)
          position = nextpos + 1
        end
        print('after', position, 'line |' .. line .. '|')
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

renderer = {
  get_size = function()
      return 1000, 1000
  end,

  begin_frame = function()
    editorchannel:push('begin_frame')
  end,

  end_frame = function()
    editorchannel:push('end_frame')
  end,

  set_clip_rect = function(x, y, w, h)
    editorchannel:push('set_clip_rect(x, y, w, h)')
  end,

  set_litecolor = function(color)
    local r, g, b, a = 255, 255, 255, 255
    if color and #color >= 3 then r, g, b = unpack(color, 1, 3) end
    if #color >= 4 then a = color[4] end
    lovr.graphics.setColor(r / 255, g / 255, b / 255, a / 255)
  end,

  draw_rect = function(x, y, w, h, color)
    x, y, w, h = x, y, w, h
    renderer.set_litecolor(color)
    math.randomseed(x + y + w + h)
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

-- global variables
ARGS = {}
SCALE = 1
PATHSEP = package.config:sub(1, 1)

local lite = require 'core'
lite.init()

lite.redraw = true
lite.frame_start = lovr.timer.getTime()

lite.run_frame()
