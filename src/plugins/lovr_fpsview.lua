-- adds "lovr:fps" command which shows FPS measurement and history
local core = require "core"
local style = require "core.style"
local Doc = require "core.doc"
local View = require "core.view"
local DocView = require "core.docview"
local command = require "core.command"
local common = require "core.common"

local lovr = { timer = require 'lovr.timer'}

----------- the FPS view ---------------

local FPSView = View:extend()


function FPSView:new()
  FPSView.super.new(self)
  self.scrollable = false
  self.yoffset = 0
  self.fps = {}
  self.maxfps = -math.huge
  self.avgfps = 0
  self.historysize = 50
  self.visible = false
  self.lastmeas = 0
  self.samplingperiod = 0.1
end


function FPSView:get_name()
  return "lovr FPS"
end


function FPSView:update()
  local t = system.get_time()
  if t - self.lastmeas > self.samplingperiod then
    self.lastmeas = t
    local fps = lovr.timer.getFPS()
    table.insert(self.fps, 1, fps)
    self.maxfps = math.max(self.maxfps, fps)
    self.avgfps = fps + (self.avgfps - fps) * 0.95 -- 1st order IIR averaging
    self.fps[self.historysize + 1] = nil
    FPSView.super.update(self)
    if self.visible then
      core.redraw = true
      self.visible = false
    end
  end
end


function FPSView:draw()
  self.visible = true
  self:draw_background(style.background)
  -- history bars
  local barcolor = (core.active_view == self) and style.selection or style.background2
  for i, bar in ipairs(self.fps) do
    renderer.draw_rect(
      self.position.x + style.padding.x + (i - 1) * (self.size.x - style.padding.x * 2) / self.historysize,
      self.position.y + style.padding.y + (1 - bar / self.maxfps) * (self.size.y - style.padding.y * 2),
      (self.size.x - style.padding.x * 2) / self.historysize - 1,
      bar / self.maxfps * (self.size.y - style.padding.y * 2),
      barcolor)
  end
  -- min and max axis values
  common.draw_text(style.code_font, style.accent, '  0 -', "right",
    self.position.x + self.size.x - style.padding.x, 
    self.position.y + (self.size.y - style.padding.y * 2),
    0, style.code_font:get_height())
  common.draw_text(style.code_font, style.accent, string.format('%03d -', self.maxfps), "right",
    self.position.x + self.size.x - style.padding.x, 
    self.position.y + style.padding.y,
    0, 0)
  -- average value
  common.draw_text(style.font, style.caret,
    string.format("%2.1f", self.avgfps), "left",
    self.position.x + style.padding.x, 
    self.position.y + style.padding.y + (1 - self.avgfps / self.maxfps) * (self.size.y - style.padding.y * 2),
    0, 0)
  -- FPS label
  common.draw_text(style.big_font, style.background,
    "FPS", "right",
    self.position.x + self.size.x - style.padding.x * 4, 
    self.position.y + self.size.y - style.padding.y * 4,
    0, 0)
end


command.add(nil, {
  ["lovr:fps"] = function()
    local node = core.root_view:get_active_node()
    local prevView = node.active_view
    node:split('down')
    node = core.root_view:get_active_node()
    node:add_view(FPSView())
    core.set_active_view(prevView)
    local parent = node:get_parent_node(core.root_view.root_node)
    parent.divider = 0.9 --shrink the fps view to 10%
  end,
})
