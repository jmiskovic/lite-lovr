lovr.conf = function(t)
  t.title, t.identity = "lite", "lite"
  t.saveprecedence = true
  t.window.width = 1000
  t.window.height = 1000
  t.modules.headset = not true -- with `false` on desktop the camera is fixed 
end
