-- serialization
local serpent = require'serpent'

local function serialize(...)
  return serpent.line({...}, {comment=false})
end


local m = {}

m.__index = m
m.editors = {}
m.loaded_fonts = {}
m.focused = nil
m.plugin_callbacks = {}
-- the general channel is used to communicate instance name to its thread
m.general_channel = lovr.thread.getChannel('lite-editors')


-- create an editor instance
function m.new()
  local self = setmetatable({}, m)
  self.name = 'lite-editor-' .. tostring(#m.editors + 1)
  self.size = {1000, 1000}
  self.current_frame = {}
  self.pose = lovr.math.newMat4()
  self:center()

  -- start the editor thread and set up the communication channels
  local threadcode = lovr.filesystem.read('lite-thread.lua')
  self.thread = lovr.thread.newThread(threadcode)
  self.thread:start()
  m.general_channel:push(serialize('new_thread', self.name)) -- announce
  self.outbount_channel = lovr.thread.getChannel(string.format('%s-events', self.name))
  self.inbound_channel = lovr.thread.getChannel(string.format('%s-render', self.name))
  table.insert(m.editors, self)
  m.set_focus(#m.editors) -- set focus to newly created editor instance
  return self
end


function m.set_focus(editorindex)
  m.focused = editorindex
  for i, editor in ipairs(m.editors) do
    editor.outbount_channel:push(serialize('set_focus', i == m.focused))
  end
end


--------- keyboard handling ---------

local function expand_key_names(key)
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
    m.editors[m.focused].outbount_channel:push(serialize('keypressed', expand_key_names(key)))
  end
end


function m.keyreleased(key, scancode)
  if m.editors[m.focused] then
    m.editors[m.focused].outbount_channel:push(serialize('keyreleased', expand_key_names(key)))
  end
end


function m.textinput(text, code)
  if m.editors[m.focused] then
    m.editors[m.focused].outbount_channel:push(serialize('textinput', text))
  end
end

--------- callbacks for all instances ---------

function m.update()
  for plugin_name, callbacks in pairs(m.plugin_callbacks) do
    if callbacks.update then callbacks.update() end
  end
  for i, instance in ipairs(m.editors) do
    instance:update_instance()
  end
end


-- needs to be called last in draw order because drawing doesn't write to depth buffer 
function m.draw()
  for plugin_name, callbacks in pairs(m.plugin_callbacks) do
    if callbacks.draw then callbacks.draw() end
  end
  for i, instance in ipairs(m.editors) do
    instance:draw_instance()
  end
end



-- inserts all important functions into callback chain, so they don't have to be called manually
-- needs to be called at the end of `main.lua` once user app functions are already defined
function m.inject_callbacks()
  local chained_callbacks = {'keypressed', 'keyreleased', 'textinput', 'update', 'draw'}
  local stored_cb = {}
  for _, cb in ipairs(chained_callbacks) do
    stored_cb[cb] = lovr[cb]
  end
  -- inject this module's cb after original callback is called
  for _, cb in ipairs(chained_callbacks) do
    lovr[cb] = function(...)
      if stored_cb[cb] then
        stored_cb[cb](...) -- call user app callback
      end
      m[cb](...) -- call own callback
    end
  end
end

--------- inbound event handlers ---------

m.event_handlers = {
  begin_frame = function(self)
    lovr.graphics.setDepthTest('lequal', false)
  end,

  end_frame = function(self)
    last_time = lovr.timer.getTime()
    lovr.graphics.setDepthTest('lequal', true)
    lovr.graphics.setStencilTest()
  end,

  set_litecolor = function(self, r, g, b, a)
    lovr.graphics.setColor(r, g, b, a)
  end,

  set_clip_rect = function(self, x, y, w, h)
    lovr.graphics.stencil(
      function() lovr.graphics.plane("fill", x + w/2, -y - h/2, 0, w, h) end)
    lovr.graphics.setStencilTest('greater', 0)
  end,

  draw_rect = function(self, x, y, w, h)
    local cx =  x + w/2
    local cy = -y - h/2
    lovr.graphics.plane( "fill", cx, cy, 0, w, h)
  end,

  draw_text = function(self, text, x, y, filename, size)
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

--------- per-instance methods ---------

function m:draw_instance()
  lovr.graphics.push()
  lovr.graphics.transform(self.pose)
  lovr.graphics.scale(1 / 1000)--math.max(self.size[1], self.size[2]))
  lovr.graphics.translate(-self.size[1] / 2, self.size[2] / 2)
  for i, draw_call in ipairs(self.current_frame) do
    local fn = m.event_handlers[draw_call[1]]
    fn(self, select(2, unpack(draw_call)))
  end
  lovr.graphics.pop()
end


function m:update_instance()
  local req_str = self.inbound_channel:pop(false)
  if req_str then
    local ok, current_frame = serpent.load(req_str)
    if ok then
      self.current_frame = current_frame
    end
  end
end


function m:resize(width, height)
  self.size = {width, height}
  self.outbount_channel:push(serialize('resize', width, height))
end


function m:center()
  if not lovr.headset then
    self.pose:set(-0, 0, -0.8)
  else
    local headpose = mat4(lovr.headset.getPose())
    local headpos = vec3(headpose)
    local pos = vec3(headpose:mul(0, 0, -0.7))
    self.pose:target(pos, headpos)
    self.pose:rotate(math.pi, 0,1,0)
  end
end


return m
