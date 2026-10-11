#!/usr/bin/env bash
# s2ar assert / diff for GitHub Actions: one call, the record's link in the job summary, the verdict as an output.
set -euo pipefail
API="${S2AR_API:-https://api.s2ar.dev}"
need() { command -v "$1" >/dev/null || { echo "::error::$1 is required"; exit 1; }; }
need curl; need jq
if [ "$TOOL" = "assert" ]; then
  [ -n "${FILE:-}" ] || { echo "::error::assert needs file"; exit 1; }
  checks="$CHECKS"
  if [ -n "${SCHEMA:-}" ]; then checks=$(jq -c --slurpfile s "$SCHEMA" '. + [{"check":"json_schema","schema":$s[0]}]' <<<"$checks"); fi
  body=$(jq -n --rawfile t "$FILE" --argjson c "$checks" '{text:$t, checks:$c}')
  out=$(curl -sS -X POST "$API/v1/assert" -H "Authorization: Bearer $S2AR_API_KEY" -H "Content-Type: application/json" --data-binary "$body")
elif [ "$TOOL" = "diff" ]; then
  [ -n "${A:-}" ] && [ -n "${B:-}" ] || { echo "::error::diff needs a and b"; exit 1; }
  body=$(jq -n --arg a "$(base64 < "$A" | tr -d '\n')" --arg b "$(base64 < "$B" | tr -d '\n')" '{a:$a, b:$b}')
  out=$(curl -sS -X POST "$API/v1/diff" -H "Authorization: Bearer $S2AR_API_KEY" -H "Content-Type: application/json" --data-binary "$body")
else
  echo "::error::tool must be assert or diff"; exit 1
fi
ok=$(jq -r '.ok // false' <<<"$out")
if [ "$ok" != "true" ]; then echo "::error::s2ar: $(jq -r '.error // "no answer"' <<<"$out")"; echo "$out" | head -c 600; exit 1; fi
verdict=$(jq -r '.verdict' <<<"$out"); sha=$(jq -r '.record_sha256 // ""' <<<"$out")
passed=$(jq -r '.passed // 0' <<<"$out"); checks_n=$(jq -r '.checks // 0' <<<"$out"); charged=$(jq -r '.charged_usd // 0' <<<"$out")
echo "verdict=$verdict" >> "$GITHUB_OUTPUT"; echo "record=$sha" >> "$GITHUB_OUTPUT"
{
  echo "### s2ar $TOOL: **$verdict** ($passed of $checks_n checks)"
  echo
  jq -r '.results[]? | "- " + (if .ok then "ok  " else "FAIL" end) + " `" + .check + "` " + ((.evidence // {}) | tostring | .[0:160])' <<<"$out"
  echo
  if [ -n "$sha" ]; then
    echo "[![assay]($API/v1/badge/$sha.svg)]($API/v1/verify/$sha) · record \`$sha\` · verify free: $API/v1/verify/$sha · charged \$$charged"
  fi
} >> "$GITHUB_STEP_SUMMARY"
echo "s2ar $TOOL: $verdict ($passed/$checks_n) record $sha"
case ",$FAIL_ON," in *",$verdict,"*) echo "::error::s2ar $TOOL verdict $verdict"; exit 1;; esac
