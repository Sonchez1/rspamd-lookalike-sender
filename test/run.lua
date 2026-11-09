--[[
Test runner. Run from the repo root with the Rspamd LuaJIT:

  docker run --rm -v "$PWD":/work -w /work rspamd/rspamd:latest rspamadm lua test/run.lua

or with any Lua 5.1+/LuaJIT that can see ./lualib and ./test on the path.
]]--

package.path = "./lualib/?.lua;./lualib/?/init.lua;./?.lua;" .. package.path

local H = require "test.helper"

require "test.spec_primitives"
require "test.spec_scorer"
require "test.spec_analyze"

local ok = H.summary()
os.exit(ok and 0 or 1)
