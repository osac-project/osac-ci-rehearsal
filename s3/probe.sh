#!/bin/bash
# What the code of a pull request can see in a pull_request_target job. Names only, never values.
echo "== variable names that look like credentials or runtime endpoints =="
env | cut -d= -f1 | grep -E '^(ACTIONS_|GITHUB_TOKEN|RUNNER_|.*SECRET|.*TOKEN|.*KEY|.*PASSWORD|OSAC)' | sort || true
echo "== a repository secret in the environment? =="
for n in OSAC_CI_APP_PRIVATE_KEY OSAC_CI_APP_ID GH_TOKEN GITHUB_TOKEN; do
  if [ -n "${!n:-}" ]; then echo "$n: PRESENT"; else echo "$n: absent"; fi
done
echo "== git credentials left in the checkout =="
git -C pr config --get-regexp 'http.*extraheader' >/dev/null 2>&1 && echo "extraheader: PRESENT" || echo "extraheader: absent"
echo "== OIDC =="
[ -n "${ACTIONS_ID_TOKEN_REQUEST_URL:-}" ] && echo "id-token request url: PRESENT" || echo "id-token request url: absent"
