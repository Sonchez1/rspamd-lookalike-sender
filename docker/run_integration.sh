#!/usr/bin/env bash
# Integration test: load the real lookalike_sender plugin into a real Rspamd (from the official
# image) and scan a dozen messages, asserting the expected symbols fire (and that benign messages
# stay clean). Requires Docker. Run from the repository root:
#
#   ./docker/run_integration.sh
#
set -euo pipefail
REPO="$(cd "$(dirname "$0")/.." && pwd)"
IMAGE="${RSPAMD_IMAGE:-rspamd/rspamd:latest}"
# On Apple Silicon the arm64 image's vectorscan uses SVE2 opcodes the emulator does not provide
# (Rspamd crashes in its own message parser, before our code). Set DOCKER_PLATFORM=linux/amd64
# to run the amd64 image under emulation instead.
PLAT_ARG=""
[ -n "${DOCKER_PLATFORM:-}" ] && PLAT_ARG="--platform=${DOCKER_PLATFORM}"

docker run --rm $PLAT_ARG -v "$REPO":/work:ro -w /work "$IMAGE" bash -eu -c '
  rspamd -c /work/docker/integration/rspamd.conf -i >/tmp/rspamd.log 2>&1 &
  RSPAMD_PID=$!
  trap "kill $RSPAMD_PID 2>/dev/null || true" EXIT

  # Wait for the normal worker to accept and scan.
  printf "From: a@b.com\nSubject: x\n\nhi\n" > /tmp/probe.eml
  for i in $(seq 1 50); do
    if rspamc -h 127.0.0.1:11333 symbols < /tmp/probe.eml >/dev/null 2>&1; then break; fi
    sleep 0.2
  done

  # message -> symbol that must appear ("-" prefix means must NOT appear / benign)
  declare -A EXPECT=(
    [01_linkedin_gmail.eml]="IMPERSONATION_SENDER"
    [02_paypal_link.eml]="IMPERSONATION_URL"
    [03_nsu_typo_link.eml]="LOOKALIKE_URL"
    [04_embedded_domain.eml]="LOOKALIKE_EMBEDDED_DOMAIN"
    [05_lure_domain.eml]="IMPERSONATION_SENDER"
    [06_typo_sender.eml]="LOOKALIKE_SENDER"
    [07_tld_swap_link.eml]="LOOKALIKE_URL"
    [08_benign_linkedin.eml]="-CLEAN"
    [09_benign_recruiter.eml]="-CLEAN"
    [10_benign_unrelated.eml]="-CLEAN"
    [11_paypal_homoglyph.eml]="IMPERSONATION_SENDER"
    [12_google_homoglyph.eml]="LOOKALIKE_SENDER"
  )
  OURS="LOOKALIKE_SENDER|LOOKALIKE_URL|LOOKALIKE_EMBEDDED_DOMAIN|IMPERSONATION_SENDER|IMPERSONATION_URL"

  fails=0
  for f in $(ls /work/docker/integration/messages | sort); do
    want="${EXPECT[$f]:-}"
    out="$(rspamc -h 127.0.0.1:11333 symbols < /work/docker/integration/messages/$f 2>/dev/null || true)"
    syms="$(echo "$out" | grep -oE "Symbol: ($OURS)" | sed "s/Symbol: //" | sort -u | tr "\n" "," )"
    if [ "$want" = "-CLEAN" ]; then
      if echo "$out" | grep -qE "Symbol: ($OURS)"; then
        echo "FAIL $f: expected no lookalike symbols, got [$syms]"; fails=$((fails+1))
      else
        echo "PASS $f: clean"
      fi
    else
      if echo "$out" | grep -qE "Symbol: $want\b"; then
        echo "PASS $f: $want present [$syms]"
      else
        echo "FAIL $f: expected $want, got [$syms]"; fails=$((fails+1))
      fi
    fi
  done

  echo
  if [ "$fails" -ne 0 ]; then echo "$fails message(s) failed"; cat /tmp/rspamd.log; exit 1; fi
  echo "integration: all messages passed"
'
