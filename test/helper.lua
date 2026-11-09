--[[
Minimal test harness: a small busted-style describe/it/assert so the specs run under plain
LuaJIT (rspamadm lua) without the busted rock. The specs also read as ordinary busted specs.
]]--

local H = { passed = 0, failed = 0, failures = {} }
local cur = "(top)"

local function deep_equal(a, b)
  if type(a) ~= type(b) then return false end
  if type(a) ~= "table" then return a == b end
  for k, v in pairs(a) do if not deep_equal(v, b[k]) then return false end end
  for k, v in pairs(b) do if a[k] == nil then return false end end
  return true
end
H.deep_equal = deep_equal

local function serialize(v, seen)
  if type(v) ~= "table" then
    if type(v) == "string" then return string.format("%q", v) end
    return tostring(v)
  end
  seen = seen or {}
  if seen[v] then return "<cycle>" end
  seen[v] = true
  local parts = {}
  local n = 0
  for i, x in ipairs(v) do parts[#parts + 1] = serialize(x, seen); n = i end
  for k, x in pairs(v) do
    if not (type(k) == "number" and k >= 1 and k <= n) then
      parts[#parts + 1] = "[" .. serialize(k, seen) .. "]=" .. serialize(x, seen)
    end
  end
  return "{" .. table.concat(parts, ",") .. "}"
end
H.serialize = serialize

function describe(name, fn)
  local prev = cur
  cur = name
  fn()
  cur = prev
end

function it(name, fn)
  local full = cur .. " :: " .. name
  local ok, err = pcall(fn)
  if ok then
    H.passed = H.passed + 1
  else
    H.failed = H.failed + 1
    H.failures[#H.failures + 1] = full .. "\n    " .. tostring(err)
  end
end

local function fail(msg) error(msg, 3) end

assert_lk = {
  equal = function(a, b, msg)
    if a ~= b then fail((msg or "equal") .. ": expected " .. serialize(b) .. ", got " .. serialize(a)) end
  end,
  same = function(a, b, msg)
    if not deep_equal(a, b) then fail((msg or "same") .. ": expected " .. serialize(b) .. ", got " .. serialize(a)) end
  end,
  is_true = function(v, msg) if not v then fail((msg or "is_true") .. ": got " .. serialize(v)) end end,
  is_false = function(v, msg) if v then fail((msg or "is_false") .. ": got " .. serialize(v)) end end,
  near = function(a, b, eps, msg)
    if math.abs(a - b) > eps then fail((msg or "near") .. ": expected " .. b .. " +/- " .. eps .. ", got " .. a) end
  end,
}

function H.summary()
  print(string.format("\n%d passed, %d failed", H.passed, H.failed))
  if H.failed > 0 then
    print("\nFAILURES:")
    for _, f in ipairs(H.failures) do print("  - " .. f) end
    return false
  end
  return true
end

return H
