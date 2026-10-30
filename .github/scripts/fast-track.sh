#!/usr/bin/env bash
# The skip of a fast track, for the three ways to ask for it (the form, the approval, the button): checks who asks and
# what for, then writes one check run of the OSAC CI app on the head commit of the pull request. A prototype: the real
# one belongs in osac-ci, which would also tell the merge queue about it.
# Everything arrives as environment variables, never as a part of the command.
set -euo pipefail

: "${GH_TOKEN:?}" "${REPO:?}" "${NUMBER:?}" "${ACTOR:?}" "${REASON:?}" "${CHECK:?}" "${VIA:?}" "${RUN_URL:?}"
SKIP="${SKIP:-E2E}"

fail() { echo "::error::$*"; exit 1; }

[[ "$NUMBER" =~ ^[0-9]+$ ]] || fail "The pull request number must be digits only."
[[ "$ACTOR" =~ ^[A-Za-z0-9-]+(\[bot\])?$ ]] || fail "Not a login."
reason="$(printf '%s' "$REASON" | tr '\n\r' '  ' | tr -s ' ' | cut -c1-200)"
[ "${#reason}" -ge 5 ] || fail "Say why in a few words (5 characters at least)."

pull="$(gh api "repos/$REPO/pulls/$NUMBER")"
[ "$(jq -r .state <<<"$pull")" = open ] || fail "Pull request #$NUMBER is not open."
author="$(jq -r .user.login <<<"$pull")"
sha="$(jq -r .head.sha <<<"$pull")"
[[ "$sha" =~ ^[0-9a-f]{40}$ ]] || fail "No head commit."

if [ "$ACTOR" = "$author" ] && [ "${ALLOW_AUTHOR:-false}" != true ]; then
  fail "The author cannot fast-track their own pull request."
fi
permission="$(gh api "repos/$REPO/collaborators/$ACTOR/permission" --jq .permission)"
case "$permission" in admin | maintain) ;; *) fail "$ACTOR may not fast-track: maintain or admin access is needed (has $permission)." ;; esac

# A change to the definition of the CI is never fast-tracked: it could remove the gates it skips.
if gh api --paginate "repos/$REPO/pulls/$NUMBER/files" --jq '.[].filename' | grep -Eq '^(\.github/|CODEOWNERS)'; then
  fail "A change to .github/ or CODEOWNERS is reviewed, never fast-tracked."
fi

title="Skipped $SKIP by $ACTOR"
summary="$(printf '### Fast track · %s\n\n**%s** by @%s, %s\n\n> %s\n\nCommit `%s`. A new commit cancels it.\n\n[Details](%s)' \
  "$VIA" "$SKIP skipped" "$ACTOR" "$(date -u +%H:%M:%S) UTC" "$reason" "${sha:0:7}" "$RUN_URL")"
body="$(jq -n --arg name "$CHECK" --arg sha "$sha" --arg title "$title" --arg summary "$summary" --arg url "$RUN_URL" \
  '{name: $name, head_sha: $sha, status: "completed", conclusion: "success", details_url: $url,
    output: {title: $title, summary: $summary}}')"
gh api -X POST "repos/$REPO/check-runs" --input - <<<"$body" --jq '"written: " + .html_url'
