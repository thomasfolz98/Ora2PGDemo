#!/usr/bin/env bash
# -------------------------------------------------------------
# advanced/rollback.sh
# Loescht die Schemata 'app_demo' und 'pkg_faktura' in Postgres.
# Oracle-Quelle bleibt unveraendert.
# Danach kann './migrate.sh' erneut ausgefuehrt werden.
# -------------------------------------------------------------
set -euo pipefail

ROOT="$(cd "$(dirname "$0")" && pwd)"
REPO_ROOT="$(cd "$ROOT/.." && pwd)"
cd "$ROOT"

msg() { printf "\n\033[1;36m==> %s\033[0m\n" "$*"; }
warn() { printf "\033[1;33m%s\033[0m\n" "$*"; }

COMPOSE="docker compose -f $REPO_ROOT/docker-compose.yml"

msg "1/3  Pruefe Postgres-Container"
if [ "$(docker inspect --format='{{.State.Status}}' postgres 2>/dev/null || echo none)" != "running" ]; then
  warn "Container 'postgres' laeuft nicht. Starte ihn..."
  $COMPOSE up -d postgres
  sleep 2
fi

msg "2/3  Drop Schemata 'app_demo' + 'pkg_faktura'"
docker exec -i postgres psql -U demo -d demo -v ON_ERROR_STOP=1 <<'SQL'
DROP SCHEMA IF EXISTS app_demo    CASCADE;
DROP SCHEMA IF EXISTS pkg_faktura CASCADE;
SQL

msg "3/3  Verifikation"
docker exec -i postgres psql -U demo -d demo <<'SQL'
SELECT schema_name FROM information_schema.schemata
 WHERE schema_name IN ('app_demo','pkg_faktura');
SQL

msg "Rollback abgeschlossen. './migrate.sh' stellt den Zustand wieder her."
