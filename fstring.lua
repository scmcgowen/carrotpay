-- Formatted String by JackMacWindows
-- Licensed as cc0
local function f(s)
  local env = setmetatable({}, {__index = _ENV})
  local f = (debug.getinfo(2, "f") or {}).func
  if f then
    for i = 1, math.huge do
      local k, v = debug.getupvalue(f, i)
      if not k then break end
      env[k] = v
    end
  end
  for i = 1, math.huge do
    local k, v = debug.getlocal(2, i)
    if not k then break end
    env[k] = v
  end
  return s:gsub("%$%b{}", function(c) return table.concat({assert(load("return " .. c:sub(3, -2), "=codestr", "t", env))()}, " ") end)
end
return f
