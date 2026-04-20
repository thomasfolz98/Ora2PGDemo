#!/usr/bin/env bash
# -------------------------------------------------------------
# basic/migrate.sh
# End-to-End-Migration Oracle XE (app_basic_demo) -> PostgreSQL.
#
# Diese Demo zeigt eine SAUBERE Migration ohne manuelle Patches:
# Ora2Pg konvertiert alle Oracle-Typen, den Index und den Trigger
# automatisch. Kein handgeschriebenes SQL noetig.
#
# Vorgehen:
#   1.  Container starten (Oracle, Postgres, ora2pg)
#   2.  Warten bis Oracle healthy
#   3.  DDL aus Oracle exportieren (TABLE, TRIGGER)
#   4.  Ziel-Schema in Postgres anlegen
#   5.  DDL einspielen
#   6.  Daten via COPY importieren
#   7.  Identity-Sequenzen nachziehen
#   8.  Verifikation
#   9.  API starten (api-basic, Port 8081)
#
# Idempotent: Jeder Lauf wipet app_basic_demo in Postgres neu auf.
# -------------------------------------------------------------
set -euo pipefail

ROOT="$(cd "$(dirname "$0")" && pwd)"
REPO_ROOT="$(cd "$ROOT/.." && pwd)"
cd "$ROOT"

COMPOSE="docker compose -f $REPO_ROOT/docker-compose.yml"

msg()  { printf "\n\033[1;36m==> %s\033[0m\n" "$*"; }
warn() { printf "\033[1;33m%s\033[0m\n" "$*"; }
err()  { printf "\033[1;31m%s\033[0m\n" "$*"; }

msg "1/8  Container starten"
$COMPOSE up -d oracle postgres

msg "2/8  Auf Oracle-Healthcheck warten"
until [ "$(docker inspect --format='{{.State.Health.Status}}' oracle-xe 2>/dev/null || echo none)" = "healthy" ]; do
  printf "."
  sleep 5
done
echo

msg "3/8  ora2pg starten und DDL exportieren"
$COMPOSE up -d ora2pg
sleep 2

docker exec ora2pg bash -lc 'cd /config-basic && ora2pg -t TABLE   -c ora2pg.conf -o tables.sql'
docker exec ora2pg bash -lc 'cd /config-basic && ora2pg -t TRIGGER -c ora2pg.conf -o triggers.sql'

msg "4/8  Postgres-Schema neu aufsetzen"
docker exec -i postgres psql -U demo -d demo -v ON_ERROR_STOP=1 <<'SQL'
DROP SCHEMA IF EXISTS app_basic_demo CASCADE;
CREATE SCHEMA app_basic_demo AUTHORIZATION demo;
SQL

msg "5/8  DDL einspielen"
import_sql() {
  local label="$1" file="$2"
  if [ -s "$file" ]; then
    printf "    %s\n" "$label"
    docker exec -i postgres bash -lc \
      'PGOPTIONS="--search_path=app_basic_demo,public" psql -U demo -d demo -v ON_ERROR_STOP=1 -f -' \
      < "$file" > /dev/null
  else
    warn "    $label: leer oder nicht vorhanden, skip"
  fi
}
import_sql "tables.sql"   migration/output/tables.sql
import_sql "triggers.sql" migration/output/triggers.sql

msg "6/8  Daten via 'ora2pg -t COPY' laden"
# FK-Trigger temporaer deaktivieren: Ora2Pg kopiert Tabellen alphabetisch
# (BESTELLUNGEN vor PRODUKTE), was die FK-Pruefung ausloesen wuerde.
docker exec -i postgres psql -U demo -d demo -v ON_ERROR_STOP=1 <<'SQL'
SET search_path = app_basic_demo, public;
ALTER TABLE bestellungen DISABLE TRIGGER ALL;
SQL
docker exec ora2pg bash -lc 'cd /config-basic && ora2pg -t COPY -c ora2pg.conf'
docker exec -i postgres psql -U demo -d demo -v ON_ERROR_STOP=1 <<'SQL'
SET search_path = app_basic_demo, public;
ALTER TABLE bestellungen ENABLE TRIGGER ALL;
SQL

msg "7/8  Identity-Sequenzen nachziehen"
docker exec -i postgres psql -U demo -d demo -v ON_ERROR_STOP=1 <<'SQL'
SET search_path = app_basic_demo, public;
SELECT setval(pg_get_serial_sequence('app_basic_demo.produkte','id'),
              (SELECT MAX(id) FROM produkte));
SELECT setval(pg_get_serial_sequence('app_basic_demo.bestellungen','id'),
              (SELECT MAX(id) FROM bestellungen));
SQL

msg "8/8  Verifikation"
docker exec -i postgres psql -U demo -d demo <<'SQL'
SET search_path = app_basic_demo, public;
SELECT 'produkte'    AS tabelle, COUNT(*) AS rows FROM produkte
UNION ALL
SELECT 'bestellungen', COUNT(*) FROM bestellungen;

SELECT b.id, p.name, b.menge, b.bestelldatum
  FROM bestellungen b
  JOIN produkte p ON p.id = b.produkt_id
 ORDER BY b.bestelldatum DESC
 LIMIT 5;
SQL

msg "9/9  API starten"
$COMPOSE up -d --build api-basic

msg "Migration abgeschlossen. API erreichbar unter http://localhost:8081/docs"
