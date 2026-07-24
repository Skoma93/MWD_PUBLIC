#!/usr/bin/env bash
set -Eeuo pipefail

bundle="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd -P)"
mode="${1:-simulation}"
common_env="$bundle/.env.common"
mode_env="$bundle/.env.$mode"

case "$mode" in simulation|hardware) ;; *) printf 'Usage: %s [simulation|hardware]\n' "$0" >&2; exit 2 ;; esac
command -v docker >/dev/null || { printf 'Docker Engine with Compose v2 is required.\n' >&2; exit 1; }
docker compose version >/dev/null
docker info >/dev/null || { printf 'Start the Docker daemon and rerun.\n' >&2; exit 1; }

created=false
for file in "$common_env" "$mode_env"; do
  if [[ ! -f "$file" ]]; then
    cp -- "$bundle/$(basename "$file").example" "$file"
    printf 'Created %s.\n' "$file" >&2
    created=true
  fi
done
if [[ "$created" == true ]]; then
  printf 'Set registry, tag, URLs, OIDC values, secrets, and mode settings; then rerun.\n' >&2
  exit 2
fi
if grep -Eq 'replace-with|example\.invalid|your-org' "$common_env" "$mode_env"; then
  printf 'Configuration still contains placeholders in %s or %s.\n' "$common_env" "$mode_env" >&2
  exit 1
fi

"$bundle/manage.sh" pull
"$bundle/manage.sh" "start-$mode"
"$bundle/manage.sh" status
printf 'Installation complete. Open the application URL configured in %s.\n' "$common_env"
