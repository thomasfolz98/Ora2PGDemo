# OracleDemo – Befehls-Cheatsheet

Schneller Zugriff auf die wichtigsten Befehle für Entwicklung, Migration,
Debugging und Demo. Ergänzend zu [README](../README.md),
[Worklog](../Worklog.md) und [PL/SQL-Migration](plsql-migration.md).

## Lifecycle

```bash
# Alles starten (Erststart ~2–4 min für Oracle-Init)
docker compose up -d

# Status / Health
docker compose ps
docker inspect --format='{{.State.Health.Status}}' oracle-xe

# End-to-End-Migration (idempotent)
./migrate.sh

# Rollback (nur Postgres-Zielschema droppen)
./rollback.sh

# Alles stoppen (Volumes bleiben)
docker compose stop

# Alles entfernen (Volumes bleiben)
docker compose down

# Alles inklusive Oracle-Daten löschen und neu
docker compose down
rm -rf docker/oracle/data/* docker/postgres/data/*
docker compose up -d
```

## Ora2Pg – Reports und Migration

Alle Ora2Pg-Befehle laufen **im `ora2pg`-Container** mit Arbeitsverzeichnis
`/config` (dort liegt `ora2pg.conf`):

```bash
# Cost Assessment (Terminal-Output)
docker exec ora2pg bash -lc \
  'cd /config && ora2pg -t SHOW_REPORT --estimate_cost -c ora2pg.conf'

# Cost Assessment als HTML (ins Host-Verzeichnis migration/)
docker exec ora2pg bash -lc \
  'cd /config && ora2pg -t SHOW_REPORT --estimate_cost --dump_as_html -c ora2pg.conf' \
  > migration/report.html

# Einzelne Export-Typen (Output nach migration/output/)
docker exec ora2pg bash -lc 'cd /config && ora2pg -t TABLE     -c ora2pg.conf'
docker exec ora2pg bash -lc 'cd /config && ora2pg -t SEQUENCE  -c ora2pg.conf'
docker exec ora2pg bash -lc 'cd /config && ora2pg -t INDEX     -c ora2pg.conf'
docker exec ora2pg bash -lc 'cd /config && ora2pg -t VIEW      -c ora2pg.conf'
docker exec ora2pg bash -lc 'cd /config && ora2pg -t FUNCTION  -c ora2pg.conf'
docker exec ora2pg bash -lc 'cd /config && ora2pg -t PROCEDURE -c ora2pg.conf'
docker exec ora2pg bash -lc 'cd /config && ora2pg -t TRIGGER   -c ora2pg.conf'
docker exec ora2pg bash -lc 'cd /config && ora2pg -t PACKAGE   -c ora2pg.conf'
docker exec ora2pg bash -lc 'cd /config && ora2pg -t COPY      -c ora2pg.conf'
```

Hilfreiche Flags: `--debug`, `--estimate_cost`, `--dump_as_html`,
`--dump_as_sheet` (CSV), `-j N` (Parallelismus beim Datenexport).

## Oracle – SQL*Plus

```bash
# Application-User (app_demo / app_demo, PDB XEPDB1)
docker exec -it oracle-xe sqlplus app_demo/app_demo@//localhost:1521/XEPDB1

# SYSDBA in der PDB
docker exec -it oracle-xe sqlplus "sys/oracle@//localhost:1521/XEPDB1 as sysdba"

# Einzelnes Statement nicht-interaktiv (Heredoc braucht -i)
docker exec -i oracle-xe sqlplus -S app_demo/app_demo@//localhost:1521/XEPDB1 <<'SQL'
SET LINES 200 PAGES 100
SELECT table_name, num_rows FROM user_tables;
EXIT
SQL

# Schema-Script einspielen (z.B. erneuter Init)
docker exec -i oracle-xe sqlplus -S app_demo/app_demo@//localhost:1521/XEPDB1 \
  < docker/oracle/init/02_tables.sql

# Zeilen pro Tabelle zählen
docker exec -i oracle-xe sqlplus -S app_demo/app_demo@//localhost:1521/XEPDB1 <<'SQL'
SELECT 'kunden'                AS t, COUNT(*) FROM kunden            UNION ALL
SELECT 'rechnungen'             , COUNT(*) FROM rechnungen          UNION ALL
SELECT 'rechnungspositionen'   , COUNT(*) FROM rechnungspositionen;
EXIT
SQL
```

## PostgreSQL – psql

```bash
# Interaktiv (demo / demo, DB demo)
docker exec -it postgres psql -U demo -d demo

# Single Query
docker exec -i postgres psql -U demo -d demo -c '\dn'
docker exec -i postgres psql -U demo -d demo -c '\dt app_demo.*'

# Heredoc (ON_ERROR_STOP=1 empfehlenswert)
docker exec -i postgres psql -U demo -d demo -v ON_ERROR_STOP=1 <<'SQL'
SET search_path = app_demo, public;
SELECT COUNT(*) FROM kunden;
SELECT COUNT(*) FROM rechnungen;
SELECT COUNT(*) FROM rechnungspositionen;
SQL

# Schema droppen (Rollback manuell)
docker exec -i postgres psql -U demo -d demo -c \
  'DROP SCHEMA IF EXISTS app_demo CASCADE;'

# Identity-Sequenzen nachziehen (passiert automatisch in migrate.sh)
docker exec -i postgres psql -U demo -d demo -v ON_ERROR_STOP=1 <<'SQL'
SELECT setval(pg_get_serial_sequence('app_demo.kunden', 'id'),
              COALESCE((SELECT MAX(id) FROM app_demo.kunden), 1));
SQL

# Dump des migrierten Schemas
docker exec postgres pg_dump -U demo -d demo -n app_demo > migration/app_demo.sql
```

## Demo-API (FastAPI)

```bash
# Logs live
docker compose logs -f api

# Health + smoke tests
curl http://localhost:8080/health
curl http://localhost:8080/kunden | jq
curl http://localhost:8080/kunden/1/rechnungen | jq
curl http://localhost:8080/rechnungen/3 | jq
curl http://localhost:8080/umsatz | jq

# Neuer Kunde
curl -X POST http://localhost:8080/kunden \
  -H 'Content-Type: application/json' \
  -d '{"vorname":"Neu","name":"Kunde","email":"neu@example.de"}'

# API neu bauen nach Code-Änderung
docker compose up -d --build api
```

Swagger-UI: <http://localhost:8080/docs>

## Troubleshooting

```bash
# Logs eines Service (letzte 200 Zeilen + follow)
docker compose logs --tail 200 -f oracle
docker compose logs --tail 200 -f postgres
docker compose logs --tail 200 -f ora2pg
docker compose logs --tail 200 -f api

# Einzelnen Container neu starten
docker compose restart oracle

# Shell im Ora2Pg-Container (fürs Debugging der Migration)
docker exec -it ora2pg bash

# Netzwerk-Check: kann ora2pg die DBs erreichen?
docker exec ora2pg bash -lc 'nc -vz oracle 1521 && nc -vz postgres 5432'

# Ora2Pg-Version / Perl-Module
docker exec ora2pg ora2pg --version
docker exec ora2pg perl -MDBD::Oracle -e 'print $DBD::Oracle::VERSION'

# Ports belegt? (v.a. 1521, 5432, 8080)
lsof -i :1521 -i :5432 -i :8080
```

**Merke:** `docker exec` braucht `-i`, sobald stdin reingegeben wird
(Heredoc oder Pipe). Ohne `-i` macht der Prozess lautlos nichts.

## Git / Publish-Vorbereitung

```bash
# Große Volumes und Reports vor dem Commit ausschließen
# (docker/oracle/data, docker/postgres/data, migration/output/ je nach Policy)
git status
git add README.md Worklog.md docs/ .claude/ docker/ api/ \
        docker-compose.yml migrate.sh rollback.sh migration/ora2pg.conf
git diff --cached --stat
```
