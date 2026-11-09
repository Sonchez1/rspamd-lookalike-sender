#!/usr/bin/env bash
# Regenerate the bundled Lua data tables (lualib/lua_lookalike/data/*.lua) and the test fixtures
# (test/fixtures/*.lua) from the impersonation-guard engine. Requires a checkout of
# impersonation-guard next to this repo (so the engine source and its esbuild are available).
#
#   ./tools/gen.sh [path-to-impersonation-guard]
#
set -euo pipefail
REPO="$(cd "$(dirname "$0")/.." && pwd)"
IG="${1:-$(cd "$REPO/../impersonation-guard" && pwd)}"

if [ ! -x "$IG/node_modules/.bin/esbuild" ]; then
  echo "esbuild not found at $IG/node_modules/.bin/esbuild; run 'npm install' in $IG first" >&2
  exit 1
fi

"$IG/node_modules/.bin/esbuild" "$REPO/tools/gen.ts" \
  --bundle --format=esm --platform=node --loader:.json=json \
  "--alias:@impersonation-guard/engine=$IG/packages/engine/src/index.ts" \
  --outfile=/tmp/rls-gen.mjs

RLS_REPO="$REPO" ENGINE_PKG="$IG/packages/engine" node /tmp/rls-gen.mjs
echo "regenerated data and fixtures"
