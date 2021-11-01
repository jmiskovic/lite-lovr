local litehost = require'lite-main'

local editor1 = litehost.new()
local editor2 = litehost.new()

function lovr.draw()
  if lovr.headset then
    lovr.graphics.translate(-0.5, 1.8, -1)
  else -- desktop simulation mode
    lovr.graphics.translate(-1, 0.5, -1.6)
  end
  editor1:draw()
  lovr.graphics.translate(1.02, 0, 0)
  editor2:draw()
end


function lovr.update()
  editor1:update()
  editor2:update()
end


lovr.keypressed = function(key, scancode, rpt)
  litehost.keypressed(key, scancode, rpt)
end


lovr.keyreleased = function(key, scancode)
  litehost.keyreleased(key, scancode)
  if key == 'f1' then
    litehost.setfocus(1)
  end
  if key == 'f2' then
    litehost.setfocus(2)
  end
end


lovr.textinput = function(text, code)
  litehost.textinput(text, code)
end
