local litehost = require'litehost'
lovr.errhand = litehost.errhand
local editor = litehost.new()


-- insert user app code here, or require project's main.lua file


litehost.inject_callbacks()
