#!/bin/bash
# With the read-only token mapped into the step: what can it write? (a 403 is the right answer for each)
api="https://api.github.com/repos/${REPO}"
code() { curl -s -o /dev/null -w '%{http_code}' -H "Authorization: Bearer ${GH_TOKEN}" -H 'Accept: application/vnd.github+json' "$@"; }
echo "comment on the pull request: $(code -X POST "$api/issues/${NUMBER}/comments" -d '{"body":"s3 probe"}')"
echo "label on the pull request:   $(code -X POST "$api/issues/${NUMBER}/labels" -d '{"labels":["s3-probe"]}')"
echo "create a ref:                $(code -X POST "$api/git/refs" -d '{"ref":"refs/heads/s3-probe","sha":"0000000000000000000000000000000000000000"}')"
echo "dispatch a workflow:         $(code -X POST "$api/actions/workflows/ci.yml/dispatches" -d '{"ref":"main"}')"
echo "read the repository:         $(code "$api")"
