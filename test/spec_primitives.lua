-- Faithfulness of the Unicode / domain primitives against engine-generated fixtures.
local lk = require "lua_lookalike"
local uni, dom, dist = lk.unicode, lk.domains, lk.distance

describe("primitives vs engine", function()
  local strings = require "test.fixtures.strings"
  it("fold_skeleton / casefold / host parsing match the engine for " .. #strings .. " strings", function()
    for _, c in ipairs(strings) do
      assert_lk.equal(uni.fold_skeleton(c.s), c.fold, "fold_skeleton(" .. c.s .. ")")
      assert_lk.equal(uni.casefold(c.s), c.casef, "casefold(" .. c.s .. ")")
      assert_lk.equal(dom.normalize_host(c.s), c.host, "normalize_host(" .. c.s .. ")")
      assert_lk.equal(dom.registrable(c.s), c.reg, "registrable(" .. c.s .. ")")
      assert_lk.equal(dom.sld(c.s), c.sld, "sld(" .. c.s .. ")")
      assert_lk.equal(dom.tld(c.s), c.tld, "tld(" .. c.s .. ")")
      assert_lk.equal(uni.is_mixed_script(c.s), c.mixed, "is_mixed_script(" .. c.s .. ")")
      assert_lk.same(dom.tokenize(c.s), c.tokens, "tokenize(" .. c.s .. ")")
      assert_lk.same(dom.subdomain_labels(c.s), c.subs, "subdomain_labels(" .. c.s .. ")")
      local exp = c.embedded
      if exp == false then exp = nil end
      assert_lk.equal(dom.embedded_domain(c.s), exp, "embedded_domain(" .. c.s .. ")")
    end
  end)

  it("osa distance matches the engine", function()
    for _, c in ipairs(require "test.fixtures.distance") do
      assert_lk.equal(dist.osa(c.a, c.b), c.d, "osa(" .. c.a .. "," .. c.b .. ")")
    end
  end)
end)
