lovr.conf = function(t)
  t.title, t.identity = "lite", "lite"
  t.saveprecedence = true
  t.window.width = 1920
  t.window.height = 1080
  t.window.fullscreen = true
  t.modules.headset = true -- set to `false` to fix the camera on desktop simulator
  --t.window.vsync = 0
end
