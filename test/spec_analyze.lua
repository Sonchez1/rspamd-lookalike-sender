-- End-to-end behaviour of the convenience analyze() wiring (Layers 1 + 2 together).
local lk = require "lua_lookalike"

local function max_link_score(r)
  local m = 0
  for _, ls in ipairs(r.link_scores) do if ls.score.probability > m then m = ls.score.probability end end
  return m
end

local function has_lookalike(r, candidate, protected)
  for _, la in ipairs(r.lookalikes) do
    if la.candidate == candidate and la.protected == protected then return true end
  end
  return false
end

describe("analyze() behaviour", function()
  it("flags a LinkedIn-support-from-gmail sender and its brand-affixed link", function()
    local det = lk.new({ "linkedin.com", "LinkedIn" })
    local r = det:analyze({ name = "LinkedIn Support", address = "li.support@gmail.com",
      hosts = { "linkedin-verify.app" } })
    assert_lk.is_true(r.sender_score.probability >= 0.5, "sender score high")
    assert_lk.is_true(max_link_score(r) >= 0.5, "a link scores high")
  end)

  it("catches a one-letter-off link host via the registrable-domain check", function()
    local det = lk.new({ "nsu.example", "Northfield State University", "NSU" })
    local r = det:analyze({ name = "Student Financial Services",
      address = "noreply@notifications.careerlink-platform.com", hosts = { "link.nsut.example" } })
    assert_lk.is_true(has_lookalike(r, "link.nsut.example", "nsu.example"), "nsut.example flagged as nsu.example")
  end)

  it("does not flag the brand's own subdomain or links", function()
    local det = lk.new({ "linkedin.com", "LinkedIn" })
    local r = det:analyze({ name = "LinkedIn", address = "linkedin@e.linkedin.com",
      hosts = { "www.linkedin.com" } })
    assert_lk.equal(#r.lookalikes, 0, "no lookalikes for the genuine domain")
    assert_lk.is_true(r.sender_score.probability < 0.5, "genuine sender scores low")
    assert_lk.is_true(max_link_score(r) < 0.5, "genuine link scores low")
  end)

  it("flags a Cyrillic-homoglyph domain as a confusable of the protected name", function()
    local det = lk.new({ "google.com", "Google" })
    -- 'gооgle.com' uses two Cyrillic 'о' (U+043E) in place of Latin 'o'.
    local homoglyph = "g\208\190\208\190gle.com"
    local r = det:analyze({ name = "Google", address = "noreply@" .. homoglyph, hosts = {} })
    assert_lk.is_true(has_lookalike(r, homoglyph, "google.com"), "homoglyph domain flagged as google.com confusable")
  end)
end)
