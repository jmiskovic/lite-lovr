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
local requestchannel  = lovr.thread.getChannel(string.format('%s-req', threadname))
local responsechannel = lovr.thread.getChannel(string.format('%s-res', threadname))

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
  generalchannel:push(serialize('keypressed', expand_keyname(key)))
end


lovr.keyreleased = function(key, scancode)
  generalchannel:push(serialize('keyreleased', expand_keyname(key)))
end


lovr.textinput = function(text, code)
  generalchannel:push(serialize('textinput', text))
end

--

local loaded_fonts = {}

local current_frame = {}
local next_frame = {}

local responders = {
  font_load = function(filename, size)
    local font = lovr.graphics.newFont(filename, size)
    font:setPixelDensity(1)
    loaded_fonts[string.format('%q:%d', filename, size)] = font
  end,
  font_get_width = function(filename, size, text)
    local font = loaded_fonts[string.format('%q:%d', filename, size)]
    assert(font)
    return font:getWidth(text)
  end,
  font_get_height = function(filename, size)
    local font = loaded_fonts[string.format('%q:%d', filename, size)]
    assert(font)
    return font:getHeight()
  end,


  begin_frame = function()
    table.insert(next_frame, {lovr.graphics.setDepthTest, 'lequal', false})
  end,

  end_frame = function()
    last_time = lovr.timer.getTime()
    table.insert(next_frame, {lovr.graphics.setDepthTest, 'lequal', true})
    table.insert(next_frame, {lovr.graphics.setStencilTest})    
    current_frame = next_frame
  end,


  set_litecolor = function(r, g, b, a)
    table.insert(next_frame, {lovr.graphics.setColor, r, g, b, a})
  end,

  set_clip_rect = function(x, y, w, h)
    table.insert(next_frame, { lovr.graphics.stencil,
      function() lovr.graphics.plane("fill", x + w/2, -y - h/2, 0, w, h) end })
    table.insert(next_frame, { lovr.graphics.setStencilTest, 'greater', 0})
  end,

  draw_rect = function(x, y, w, h)
    local cx =  x + w/2
    local cy = -y - h/2
    table.insert(next_frame, {lovr.graphics.plane, "fill", cx, cy, 0, w, h})
  end,

  draw_text = function(text, x, y, filename, size)
    local font = loaded_fonts[string.format('%q:%d', filename, size)]
    assert(font)
    table.insert(next_frame, {lovr.graphics.setFont, font})
    table.insert(next_frame, {lovr.graphics.print, text, x, -y, 0, 1, 0, 0,1,0, nil, 'left', 'top'})
    return font:getWidth(text)
  end,

}


function lovr.draw()
  lovr.graphics.push()
  if lovr.headset then
    lovr.graphics.translate(-0.5, 1.8, -1)
  else -- desktop simulation mode
    lovr.graphics.translate(-0.5, 0.5, -0.8)
  end
  lovr.graphics.scale(1 / 1000)
  for i, draw_call in ipairs(current_frame) do
    draw_call[1](select(2, unpack(draw_call)))
  end
  lovr.graphics.pop()
end


function lovr.update(dt)
  local timeout = 0.01
  local time = lovr.timer.getTime()
  while lovr.timer.getTime() < time + 0.05 do
    local req_str = requestchannel:pop(false)
    if req_str then
      local req = deserialize(req_str)
      local responder = responders[req[1]]
      if responder then
        local response = responder(select(2, unpack(req)))
        if response then
          responsechannel:push(serialize(req[1], response))
        end
        if req[1] == 'end_frame' then
          break
        end
      else
        print('no responder fn for', req[1])
      end
    else
      --break
    end
  end
end
