# Pull request for rspamd/rspamd

**Title:** Add `lookalike_sender` module: confusable/typo sender & URL-host impersonation scoring

---

## Motivation

Rspamd detects phishing by comparing a URL's visible text against its real destination
(`phishing` module) and by matching hosts against phishing/Phishtank maps. Neither catches the
large class of **brand-impersonation that is internally consistent**: a message whose From name is
a confusable or one-letter typo of a brand, a sender that claims to be a brand from a look-alike or
free-webmail domain, or a link that honestly points at `paypal-secure-center.com` /
`login.linkedin.com.secure-verify.co` — where the visible text and the `href` agree, so there is no
display/href mismatch to flag.

This module adds deterministic, explainable detection of look-alike **senders** and
brand-impersonating **link hosts** against an operator-configured protected set. It is a Lua port of
Layers 1 and 2 of the open-source `impersonation-detector` engine
(https://github.com/Sonchez1/impersonation-detector; preprint
[doi:10.5281/zenodo.23716571](https://doi.org/10.5281/zenodo.23716571); Internet-Draft
[draft-ezema-lookalike-sender-detection](https://datatracker.ietf.org/doc/draft-ezema-lookalike-sender-detection/)).

## Design

The module is in two parts:

- **`lualib/lua_lookalike/`** — a pure-Lua library with no Rspamd dependency, so it is unit-testable
  in isolation. It implements:
  - **Layer 1:** UTS #39 confusable skeleton (section 4) and mixed-script (section 5) checks,
    Damerau–Levenshtein typo distance (length-scaled thresholds), and embedded-domain detection,
    of the From display name, the From domain and each URL host against the protected set.
  - **Layer 2:** a logistic regression over 23 named features of the sender and of each link host
    (`domain_skeleton_match`, `domain_close_typo`, `domain_tld_swap`, `domain_brand_affix`,
    `domain_lure_words`, `domain_embeds_foreign_domain`, `display_claims_brand_off_domain`,
    `domain_free_mail`, invisible-character and mixed-script flags, …), using the model weights
    shipped with the engine. Each score reports the features that drove it.
  - The Unicode confusables and script data and the model weights are bundled as compact Lua tables
    generated from the engine (`lualib/lua_lookalike/data/`), so the module is self-contained and
    does not depend on the host ICU version for its verdicts.

- **`src/plugins/lua/lookalike_sender.lua`** — the Rspamd glue: reads `rspamd_config:get_all_opt`,
  builds the detector from the configured protected set, and in a registered callback reads
  `task:get_from('mime')` and `task:get_urls()`, runs Layers 1–2, and emits symbols via
  `task:insert_result` with the offending value and a human-readable reason as the option.

### Symbols

| Symbol | Default | Meaning |
|---|---|---|
| `LOOKALIKE_SENDER` | 7.0 | From name/domain is a confusable or typo of a protected name |
| `LOOKALIKE_URL` | 5.0 | A URL host is a confusable or typo of a protected name |
| `LOOKALIKE_EMBEDDED_DOMAIN` | 5.0 | A URL host hides another registrable domain in its subdomains |
| `IMPERSONATION_SENDER` | 4.0 × p | Logistic impersonation score for the sender (scaled by probability) |
| `IMPERSONATION_URL` | 3.0 × p | Logistic impersonation score for a URL host (scaled by probability) |

The module is disabled unless the operator configures a non-empty `protected` set in
`local.d/lookalike_sender.conf`, so it has no effect on existing installs until deliberately enabled.

## How it differs from the existing `phishing` module

`phishing` answers "does this URL's visible text lie about where it goes?" — it compares the
anchor text's host against the `href` host and consults phishing maps. `lookalike_sender` answers a
different question — "who do the sender and the link hosts *resemble*?" — scoring display names,
addresses and hosts against a configured protected set with confusable-skeleton, typo, affix, lure
and embedded-domain checks, and it reasons about the **sender**, which `phishing` does not. It fires
on internally-consistent impersonation (honest text→href, look-alike sender) that `phishing` passes.
The two are complementary and can run together.

## Test evidence

- **Unit tests** (`test/`, run with `rspamadm lua test/run.lua`): the Lua port is checked against
  fixtures generated from the reference engine — 46 strings (skeleton/casefold/registrable/
  tokenise/mixed-script), 296 sender feature-vectors, 296 logistic scores and 300 lookalike checks,
  all drawn from the engine's benchmark. All pass; the port reproduces the engine's outputs exactly
  (probabilities within 1e-9).
- **Integration test** (`docker/run_integration.sh`): the plugin is loaded into a real Rspamd from
  the official image and scans twelve messages; the expected symbols fire on the ten impersonation
  cases and the two benign messages stay clean.

## Notes for review

- No new C code, no new dependencies; pure Lua plus generated data tables.
- No network or async I/O in the callback; verdicts are deterministic.
- The bundled Unicode data derives from the UCD (UTS #39) and is redistributable under the Unicode
  License; the module code is MIT. (Please advise if Apache-2.0 relicensing of the module code is
  required for inclusion — I am happy to relicense my own code accordingly.)
- `data/README.md` documents the one normalization edge (cross-code-point canonical reordering of
  stacked combining marks) that the compact per-code-point tables do not reproduce; it cannot occur
  in a hostname and is absent from the benchmark.
