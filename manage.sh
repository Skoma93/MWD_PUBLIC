#!/usr/bin/env bash
set -Eeuo pipefail

bundle="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd -P)"
common_env="$bundle/.env.common"
base=(docker compose --env-file "$common_env" -f "$bundle/compose.yml")
command="${1:-status}"

command -v docker >/dev/null || { printf 'Docker with Compose v2 is required.\n' >&2; exit 1; }
if [[ ! -f "$common_env" ]]; then
  cp -- "$bundle/.env.common.example" "$common_env"
  printf 'Created %s. Replace every placeholder, then rerun.\n' "$common_env" >&2
  exit 1
fi
if grep -Eq 'replace-with|example\.invalid|your-org' "$common_env"; then
  printf 'Replace every placeholder in %s before deployment.\n' "$common_env" >&2
  exit 1
fi

case "$command" in
  pull) "${base[@]}" pull ;;
  start-simulation)
    "${base[@]}" --env-file "$bundle/.env.simulation" -f "$bundle/compose.simulation.yml" pull
    "${base[@]}" --env-file "$bundle/.env.simulation" -f "$bundle/compose.simulation.yml" up -d
    ;;
  start-hardware)
    "${base[@]}" --env-file "$bundle/.env.hardware" -f "$bundle/compose.hardware.yml" pull
    "${base[@]}" --env-file "$bundle/.env.hardware" -f "$bundle/compose.hardware.yml" up -d
    ;;
  status) "${base[@]}" ps ;;
  logs) "${base[@]}" logs --follow --tail 200 ;;
  stop) "${base[@]}" stop ;;
  *) printf 'Usage: %s {pull|start-simulation|start-hardware|status|logs|stop}\n' "$0" >&2; exit 2 ;;
esac
