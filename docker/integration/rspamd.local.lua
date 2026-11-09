-- Loaded by rspamd at config time (the `lua = ...` option). Puts the bundled library on the
-- Lua path and loads the plugin, so the integration test exercises the real module.
package.path = package.path .. ";/work/lualib/?.lua;/work/lualib/?/init.lua"
dofile("/work/src/plugins/lua/lookalike_sender.lua")
