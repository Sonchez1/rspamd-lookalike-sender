# rspamd-lookalike-sender

An [Rspamd](https://rspamd.com) module that detects **look-alike senders and brand-impersonating
link hosts** against an operator-configured protected set. It is a faithful Lua port of Layers 1
and 2 of the [impersonation-detector](https://github.com/Sonchez1/impersonation-detector) engine:

- **Layer 1 — lookalike detection.** UTS #39 confusable-skeleton and mixed-script checks, plus
  typo (Damerau–Levenshtein) distance and embedded-domain detection, of the From display name, the
  From domain, and every URL host against the protected set.
- **Layer 2 — explainable sender score.** A logistic model over 23 named features of the sender and
  of each link host (brand claimed off-domain, lure-word domain, brand glued to affixes, TLD swap,
  invisible characters, free-webmail role claims, …), using the model weights shipped with the
  engine. Every score lists the features that drove it.

Each finding is emitted as an Rspamd symbol whose option is a human-readable reason.

All logic is local and deterministic; the module makes **no network requests**.

## How it differs from the built-in `phishing` module

Rspamd's `phishing` module compares the **visible text of a URL against its real `href`** (and
checks hosts against phishing maps): it catches links whose displayed destination lies about where
they go. This module asks a different question — **who does the sender, or a link host, resemble?** —
by scoring display names, addresses and hosts against a configured set of protected brands and
domains with the confusable-skeleton, typo, affix, lure and embedded-domain checks of the
impersonation-detector engine. It fires even when the visible text and the `href` agree (a message
that honestly links to `paypal-secure-center.com`), and it reasons about the **sender**, which
`phishing` does not. The two are complementary.

## Layout

```
lualib/lua_lookalike/        Pure-Lua library (no Rspamd dependency; unit-testable)
  init.lua                   analyze(): Layers 1+2 over a sender + link hosts
  unicode.lua domains.lua distance.lua lookalike.lua features.lua scorer.lua
  data/                      Bundled Unicode + model tables (generated; see data/README.md)
src/plugins/lua/lookalike_sender.lua   The Rspamd plugin (register_symbol, task callback)
conf/lookalike_sender.conf             Default module config
test/                        Unit tests (run with rspamadm lua) + engine-parity fixtures
docker/                      Docker integration test against real Rspamd
tools/                       gen.ts / gen.sh: regenerate data + fixtures from the engine
```

## Install

1. Copy the library and the plugin into your Rspamd tree (or point Rspamd's Lua path at them):
   - `lualib/lua_lookalike/` → `$LOCAL_CONFDIR/lua/lua_lookalike/` (or anywhere on `lua_path`)
   - `src/plugins/lua/lookalike_sender.lua` → loaded as a plugin (e.g. via
     `rspamd.local.lua`: `dofile("…/lookalike_sender.lua")`, or by placing it with the other
     Lua plugins when building Rspamd).
2. Configure the protected set in `$LOCAL_CONFDIR/local.d/lookalike_sender.conf`:

   ```ucl
   lookalike_sender {
     protected = ["example.com", "Example", "chase.com", "Chase"];
     score_threshold = 0.5;
   }
   ```

   The module is disabled until `protected` is non-empty. See `conf/lookalike_sender.conf` for all
   options and default symbol weights.

## Symbols

| Symbol | Default score | Meaning |
|---|---|---|
| `LOOKALIKE_SENDER` | 7.0 | From name/domain is a confusable or typo of a protected name |
| `LOOKALIKE_URL` | 5.0 | A URL host is a confusable or typo of a protected name |
| `LOOKALIKE_EMBEDDED_DOMAIN` | 5.0 | A URL host hides another registrable domain in its subdomains |
| `IMPERSONATION_SENDER` | 4.0 × p | Logistic impersonation score for the sender (scaled by probability) |
| `IMPERSONATION_URL` | 3.0 × p | Logistic impersonation score for a URL host (scaled by probability) |

Scores are defaults; tune them in `local.d/groups.conf` as usual.

## Tests

The logic is pure Lua and is tested against fixtures generated from the engine, so the port is
verifiably faithful (the fixtures cover 46 strings, 296 sender feature-vectors, 296 scores and 300
lookalike checks drawn from the engine's own benchmark). Run them with Rspamd's LuaJIT:

```bash
docker run --rm -v "$PWD":/work -w /work rspamd/rspamd:latest rspamadm lua test/run.lua
```

(or with any Lua 5.1+/LuaJIT that can see `./lualib` and `./test` on the path.)

### Integration test (real Rspamd)

`docker/run_integration.sh` loads the plugin into a real Rspamd from the official image and scans a
dozen messages, asserting the expected symbols fire and benign messages stay clean:

```bash
./docker/run_integration.sh
```

> On Apple Silicon the `arm64` image's vectorscan uses SVE2 instructions the emulator does not
> provide, so Rspamd crashes in its own message parser before reaching this module. Run the amd64
> image instead: `DOCKER_PLATFORM=linux/amd64 ./docker/run_integration.sh`. This has been verified
> to pass all twelve messages.

## Regenerating the bundled data

The Unicode tables and parity fixtures are generated from the engine. With an `impersonation-guard`
checkout beside this repo (and `npm install` run there):

```bash
./tools/gen.sh ../impersonation-guard
```

## License

MIT © Sochima Ezema. The bundled Unicode data derives from the Unicode Character Database
(UTS #39 confusables and script data) and is redistributable under the Unicode License.
