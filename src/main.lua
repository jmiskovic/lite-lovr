local serpent = require'serpent'

local function serialize(...)
  return serpent.line({...}, {comment=false})
end

local function deserialize(line)
  local ok, res = serpent.load(line)
  assert(ok, 'invalid loading of string "' .. line .. '"')
  return res
end


local threadcode = lovr.filesystem.read('thread_litely.lua')
thread = lovr.thread.newThread(threadcode)
thread:start()

local generalchannel = lovr.thread.getChannel('lite-editors')
local threadname = 'lite-editor-1'
generalchannel:push(serialize('new_thread', threadname))
local eventschannel = lovr.thread.getChannel(string.format('%s-events', threadname))
local renderchannel = lovr.thread.getChannel(string.format('%s-render', threadname))

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
  eventschannel:push(serialize('keypressed', expand_keyname(key)))
end


lovr.keyreleased = function(key, scancode)
  eventschannel:push(serialize('keyreleased', expand_keyname(key)))
end


lovr.textinput = function(text, code)
  eventschannel:push(serialize('textinput', text))
end

-- rendering

local loaded_fonts = {}

local current_frame = {}
local next_frame = {}

local render_fns = {
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
    lovr.graphics.setStencilTest( 'greater', 0)
  end,

  draw_rect = function(x, y, w, h)
    local cx =  x + w/2
    local cy = -y - h/2
    lovr.graphics.plane( "fill", cx, cy, 0, w, h)
  end,

  draw_text = function(text, x, y, filename, size)
    local fontname = string.format('%q:%d', filename, size)
    local font = loaded_fonts[fontname]
    if not font then
      font = lovr.graphics.newFont(filename, size)
      font:setPixelDensity(1)
      loaded_fonts[fontname] = font
    end
    lovr.graphics.setFont(font)
    lovr.graphics.print(text, x, -y, 0, 1, 0, 0,1,0, nil, 'left', 'top')
  end,
}


function lovr.update(dt)
  local timeout = 0.01
  local time = lovr.timer.getTime()

  local req_str = renderchannel:pop(false)
  if req_str then
    local ok
    ok, current_frame = serpent.load(req_str)
    assert(ok)
  end
end


function lovr.draw()
  lovr.graphics.push()
  if lovr.headset then
    lovr.graphics.translate(-0.5, 1.8, -1)
  else -- desktop simulation mode
    lovr.graphics.translate(-0.5, 0.5, -0.8)
  end
  lovr.graphics.scale(1 / 1000)
  for i, draw_call in ipairs(current_frame) do
    local fn = render_fns[draw_call[1]]
    fn(select(2, unpack(draw_call)))
  end
  lovr.graphics.pop()
end
