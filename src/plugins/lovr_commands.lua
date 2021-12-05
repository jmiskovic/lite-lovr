-- adds few LOVR environment commands
local command = require "core.command"

-- code to be executed on main thread host
renderer.register_plugin('center', {
  center = function(self)
    self:center()
  end,

  restart_lovr = function(self)
    -- warning: destroys lite context and any unsaved changes
    lovr.event.restart()
  end
})

-- triggering host functions from the lite plugin
command.add(nil, {
  ["lovr:center"] = function()
    renderer.add_event('center')
  end,

  ["lovr:restart"] = function()
    renderer.add_event('restart_lovr')
  end,
  })
