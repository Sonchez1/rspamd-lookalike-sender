-- Faithfulness of Layer 2 (features + logistic score) and Layer 1 (lookalike) vs the engine.
local lk = require "lua_lookalike"
local feat, scorer, look = lk.features, lk.scorer, lk.lookalike
local NAMES = feat.FEATURE_NAMES

local function check_features(got, expected, label)
  for _, k in ipairs(NAMES) do
    local want = expected[k] or 0
    assert_lk.equal(got[k], want, label .. " feature " .. k)
  end
end

describe("Layer 2 features vs engine", function()
  local cases = require "test.fixtures.features"
  it("extracts the 23 features identically for " .. #cases .. " senders", function()
    for _, c in ipairs(cases) do
      local ext = feat.new(c.protected)
      ext.brand_on_own_domain_is_benign = true
      local got = ext:extract({ display_name = c.name, address = c.address })
      check_features(got, c.features, "[" .. (c.address or "") .. "]")
    end
  end)
end)

describe("Layer 2 score vs engine", function()
  local cases = require "test.fixtures.scores"
  it("produces the same logistic probability for " .. #cases .. " senders", function()
    for _, c in ipairs(cases) do
      local s = scorer.new(c.protected)
      s.extractor.brand_on_own_domain_is_benign = true
      local p = s:score({ display_name = c.name, address = c.address }).probability
      assert_lk.near(p, c.prob, 1e-9, "[" .. (c.address or "") .. "]")
    end
  end)

  it("scores link-host domains identically", function()
    for _, c in ipairs(require "test.fixtures.domscores") do
      local s = scorer.new(c.protected)
      s.extractor.brand_on_own_domain_is_benign = true
      local r = s:score_domain(c.host)
      assert_lk.near(r.probability, c.prob, 1e-9, "domscore " .. c.host)
      check_features(r.features, c.features, "domscore " .. c.host)
    end
  end)
end)

describe("Layer 1 lookalike vs engine", function()
  local cases = require "test.fixtures.lookalike"
  it("finds the same matches, reasons and distances for " .. #cases .. " candidates", function()
    for _, c in ipairs(cases) do
      local det = look.new(c.protected)
      local got = det:check(c.candidate)
      assert_lk.equal(#got, #c.matches, "match count for " .. c.candidate)
      for i, m in ipairs(c.matches) do
        assert_lk.equal(got[i].protected, m.protected, "match " .. i .. " protected for " .. c.candidate)
        assert_lk.equal(got[i].distance, m.distance, "match " .. i .. " distance for " .. c.candidate)
        assert_lk.same(got[i].reasons, m.reasons, "match " .. i .. " reasons for " .. c.candidate)
      end
    end
  end)
end)
