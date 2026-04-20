#!/usr/bin/env bash
# -------------------------------------------------------------
# advanced/migrate.sh
# Reproduzierbare End-to-End-Migration Oracle XE (app_demo) -> PostgreSQL.
#
# Dieses Demo zeigt eine KOMPLEXE Migration mit PL/SQL-Package,
# Triggern und einem manuellen Patch fuer den Rueckgabetyp.
#
# Vorgehen:
#   1.  Container starten
#   2.  Auf Oracle-Healthcheck warten
#   3.  ora2pg-advanced starten
#   4.  DDL exportieren (TABLE, SEQUENCE, VIEW, TRIGGER, PACKAGE, FUNCTION, PROCEDURE)
#   5.  Ziel-Schemata in Postgres droppen + neu anlegen (app_demo + pkg_faktura)
#   6.  DDL einspielen
#   7.  Daten via COPY laden
#   8.  Identity-Sequenzen nachziehen
#   9.  Patches einspielen (z.B. numeric-Rueckgabetypen fuer Package-Funktionen)
#   10. Verifikation inkl. Smoke-Test pkg_faktura.kunde_umsatz(1)
#
# Idempotent: Jeder Lauf wipet app_demo + pkg_faktura in Postgres neu auf.
# -------------------------------------------------------------
set -euo pipefail

ROOT="$(cd "$(dirname "$0")" && pwd)"
REPO_ROOT="$(cd "$ROOT/.." && pwd)"
cd "$ROOT"

COMPOSE="docker compose -f $REPO_ROOT/docker-compose.yml"

msg()  { printf "\n\033[1;36m==> %s\033[0m\n" "$*"; }
warn() { printf "\033[1;33m%s\033[0m\n" "$*"; }
err()  { printf "\033[1;31m%s\033[0m\n" "$*"; }

msg "1/10  Container starten"
$COMPOSE up -d oracle postgres

msg "2/10  Auf Oracle-Healthcheck warten"
until [ "$(docker inspect --format='{{.State.Health.Status}}' oracle-xe 2>/dev/null || echo none)" = "healthy" ]; do
  printf "."
  sleep 5
done
echo

msg "3/10  ora2pg-advanced starten"
$COMPOSE up -d ora2pg-advanced
sleep 2

msg "4/10  DDL aus Oracle exportieren"
docker exec ora2pg-advanced bash -lc 'cd /config && ora2pg -t TABLE     -c ora2pg.conf -o tables.sql'
docker exec ora2pg-advanced bash -lc 'cd /config && ora2pg -t SEQUENCE  -c ora2pg.conf -o sequences.sql'
docker exec ora2pg-advanced bash -lc 'cd /config && ora2pg -t VIEW      -c ora2pg.conf -o views.sql'
docker exec ora2pg-advanced bash -lc 'cd /config && ora2pg -t TRIGGER   -c ora2pg.conf -o triggers.sql'
docker exec ora2pg-advanced bash -lc 'cd /config && ora2pg -t PACKAGE   -c ora2pg.conf -o package.sql'
docker exec ora2pg-advanced bash -lc 'cd /config && ora2pg -t FUNCTION  -c ora2pg.conf -o functions.sql'
docker exec ora2pg-advanced bash -lc 'cd /config && ora2pg -t PROCEDURE -c ora2pg.conf -o procedures.sql'

msg "5/10  Postgres-Schemata neu aufsetzen"
docker exec -i postgres psql -U demo -d demo -v ON_ERROR_STOP=1 <<'SQL'
DROP SCHEMA IF EXISTS app_demo    CASCADE;
DROP SCHEMA IF EXISTS pkg_faktura CASCADE;
CREATE SCHEMA app_demo AUTHORIZATION demo;
ALTER ROLE demo SET search_path = app_demo, pkg_faktura, public;
SQL

msg "6/10  DDL in Postgres einspielen (tables -> sequences -> views -> triggers -> package)"
import_sql() {
  local label="$1" file="$2"
  if [ -s "$file" ]; then
    printf "    %s\n" "$label"
    docker exec -i postgres bash -lc \
      'PGOPTIONS="--search_path=app_demo,public" psql -U demo -d demo -v ON_ERROR_STOP=1 -f -' \
      < "$file" > /dev/null
  else
    warn "    $label: $file fehlt oder leer, skip"
  fi
}
import_sql "tables.sql"     migration/output/tables.sql
import_sql "sequences.sql"  migration/output/sequences.sql
import_sql "views.sql"      migration/output/views.sql
import_sql "triggers.sql"   migration/output/triggers.sql
import_sql "package.sql"    migration/output/package.sql
import_sql "functions.sql"  migration/output/functions.sql
import_sql "procedures.sql" migration/output/procedures.sql

msg "7/10  Daten via 'ora2pg -t COPY' laden"
docker exec ora2pg-advanced bash -lc 'cd /config && ora2pg -t COPY -c ora2pg.conf'

msg "8/10  Identity-Sequenzen nachziehen"
docker exec -i postgres psql -U demo -d demo -v ON_ERROR_STOP=1 <<'SQL'
SET search_path = app_demo, pkg_faktura, public;
SELECT setval(pg_get_serial_sequence('app_demo.kunden','id'),              (SELECT MAX(id) FROM kunden));
SELECT setval(pg_get_serial_sequence('app_demo.rechnungen','id'),          (SELECT MAX(id) FROM rechnungen));
SELECT setval(pg_get_serial_sequence('app_demo.rechnungspositionen','id'), (SELECT MAX(id) FROM rechnungspositionen));
SQL

msg "9/10  Patches aus migration/output/patches/ einspielen"
if compgen -G "migration/output/patches/*.sql" > /dev/null; then
  for p in migration/output/patches/*.sql; do
    printf "    %s\n" "$(basename "$p")"
    docker exec -i postgres bash -lc \
      'PGOPTIONS="--search_path=app_demo,pkg_faktura,public" psql -U demo -d demo -v ON_ERROR_STOP=1 -f -' \
      < "$p" > /dev/null
  done
else
  warn "    keine Patches vorhanden"
fi

msg "10/10  Verifikation"
docker exec -i postgres psql -U demo -d demo <<'SQL'
SET search_path = app_demo, pkg_faktura, public;
SELECT 'kunden' AS tabelle, COUNT(*) AS rows FROM kunden
UNION ALL SELECT 'rechnungen', COUNT(*) FROM rechnungen
UNION ALL SELECT 'rechnungspositionen', COUNT(*) FROM rechnungspositionen;
SELECT kundenname, land, anzahl_rechnungen, umsatz_bezahlt, umsatz_offen
  FROM v_kunde_umsatz ORDER BY umsatz_bezahlt DESC LIMIT 5;
SQL

msg "Smoke-Test pkg_faktura.kunde_umsatz(1) == 880.60"
SMOKE=$(docker exec -i postgres psql -U demo -d demo -t -A -c \
  "SELECT pkg_faktura.kunde_umsatz(1);" 2>/dev/null | tr -d '[:space:]')
if [ "$SMOKE" = "880.60" ]; then
  printf "    OK  (%s)\n" "$SMOKE"
else
  err "    WARNUNG: erwartet 880.60, bekommen '$SMOKE'"
  err "    Pruefe migration/output/package.sql und Patches in migration/output/patches/."
fi

msg "Migration abgeschlossen. API erreichbar unter http://localhost:8080/docs"
