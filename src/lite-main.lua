local m = {}
m.__index = m
m.editors = {}
m.loaded_fonts = {}
m.focused = nil
--[[ The general channel is used to communicate the name of editor instance
to its thread. In addition to general channel, each thread gets assigned with
an events channel for receiving input events and the render channel for sending
draw calls to main thread to be rendered. --]]
m.generalchannel = lovr.thread.getChannel('lite-editors')

-- serialization
local serpent = require'serpent'

local function serialize(...)
  return serpent.line({...}, {comment=false})
end


-- create an editor instance
function m.new()
  local self = setmetatable({}, m)
  self.name = 'lite-editor-' .. tostring(#m.editors + 1)
  self.size = {1000, 1000}
  self.current_frame = {}
  -- start the editor thread and set up the communication channels
  local threadcode = lovr.filesystem.read('lite-thread.lua')
  self.thread = lovr.thread.newThread(threadcode)
  self.thread:start()
  m.generalchannel:push(serialize('new_thread', self.name)) -- announce
  self.eventschannel = lovr.thread.getChannel(string.format('%s-events', self.name))
  self.renderchannel = lovr.thread.getChannel(string.format('%s-render', self.name))
  table.insert(m.editors, self)
  m.setfocus(#m.editors) -- set focus to newly created editor instance
  return self
end


function m.setfocus(editorindex)
  m.focused = editorindex
  for i, editor in ipairs(m.editors) do
    editor.eventschannel:push(serialize('set_focus', i == m.focused))
  end
end


-- keyboard handling
local function expandkeyname(key)
  if key:sub(1, 2) == "kp" then
    return "keypad " .. key:sub(3)
  end
  if key:sub(2) == "ctrl" or key:sub(2) == "shift" or key:sub(2) == "alt" or key:sub(2) == "gui" then
    if key:sub(1, 1) == "l" then return "left " .. key:sub(2) end
    return "right " .. key:sub(2)
  end
  return key
end


function m.keypressed(key, scancode, rpt)
  if m.editors[m.focused] then
    m.editors[m.focused].eventschannel:push(serialize('keypressed', expandkeyname(key)))
  end
end


function m.keyreleased(key, scancode)
  if m.editors[m.focused] then
    m.editors[m.focused].eventschannel:push(serialize('keyreleased', expandkeyname(key)))
  end
end


function m.textinput(text, code)
  if m.editors[m.focused] then
    m.editors[m.focused].eventschannel:push(serialize('textinput', text))
  end
end

--------- per-instance methods ---------

local render_fns = { -- map lite rendering commands into LOVR draw calls
  begin_frame = function()
    lovr.graphics.setDepthTest('lequal', false)
  end,

  end_frame = function()
    last_time = lovr.timer.getTime()
    lovr.graphics.setDepthTest('lequal', true)
    lovr.graphics.setStencilTest()   
  end,


  set_litecolor = function(r, g, b, a)
    lovr.graphics.setColor(r, g, b, a)
  end,

  set_clip_rect = function(x, y, w, h)
    lovr.graphics.stencil(
      function() lovr.graphics.plane("fill", x + w/2, -y - h/2, 0, w, h) end)
    lovr.graphics.setStencilTest('greater', 0)
  end,

  draw_rect = function(x, y, w, h)
    local cx =  x + w/2
    local cy = -y - h/2
    lovr.graphics.plane( "fill", cx, cy, 0, w, h)
  end,

  draw_text = function(text, x, y, filename, size)
    local fontname = string.format('%q:%d', filename, size)
    local font = m.loaded_fonts[fontname]
    if not font then
      font = lovr.graphics.newFont(filename, size)
      font:setPixelDensity(1)
      m.loaded_fonts[fontname] = font
    end
    lovr.graphics.setFont(font)
    lovr.graphics.print(text, x, -y, 0,  1,  0, 0,1,0, nil, 'left', 'top')
  end,
}

function m:draw(...)
  local stencilCount, stencilsMax = 0, 120
  lovr.graphics.push()
  lovr.graphics.transform(...)
  lovr.graphics.scale(1 / 1000)--math.max(self.size[1], self.size[2]))
  lovr.graphics.translate(-self.size[1] / 2, self.size[2] / 2)
  for i, draw_call in ipairs(self.current_frame) do
    local fn = render_fns[draw_call[1]]
    fn(select(2, unpack(draw_call)))
  end
  lovr.graphics.pop()
end


function m:update(dt)
  local req_str = self.renderchannel:pop(false)
  if req_str then
    local ok, current_frame = serpent.load(req_str)
    if ok then
      self.current_frame = current_frame
    end
  end
end


function m:resize(width, height)
  self.size = {width, height}
  self.eventschannel:push(serialize('resize', width, height))
end


return m
