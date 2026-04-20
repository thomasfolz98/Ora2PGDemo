# Worklog – Oracle Demo Migration

## 2026-04-17 – Projekt-Initialisierung & Review

### Umgebung

- Host: MacBook Pro, Apple M1 Pro, 32 GB RAM, macOS 26.3.1
- Docker Desktop mit Rosetta-Emulation für amd64-Images

### Projektstruktur (Ist-Zustand)

```
OracleDemo/
├── CLAUDE.md
├── docker-compose.yml
├── agents/            (infra, dba, migration, dev – Rollenbeschreibungen)
├── api/               (leer)
├── db/                (leer)
├── docs/              (leer)
├── docker/
│   ├── oracle/init.sql   (legt app_demo-Schema an – wird aktuell NICHT ausgeführt)
│   ├── oracle/data/      (Oracle-Tablespace-Volume)
│   ├── postgres/data/    (Postgres-Volume)
│   └── ora2pg/Dockerfile (Ubuntu 22.04 + Instant Client 21.12 + Ora2Pg v24.0)
└── migration/
    ├── ora2pg.conf
    └── report.html       (erster SHOW_REPORT-Lauf, Schema leer)
```

### Docker-Status

| Container    | Image                      | Arch     | Platform-Flag  | Status   | RAM    | Ports         |
| ------------ | -------------------------- | -------- | -------------- | -------- | ------ | ------------- |
| oracle-xe    | gvenzl/oracle-xe:21-slim   | x86_64   | linux/amd64    | running  | 3,1 GB | 1521, 5500    |
| postgres     | postgres:15                | aarch64  | (nativ)        | running  | 47 MB  | 5432          |
| ora2pg       | custom (Ubuntu 22.04)      | x86_64   | linux/amd64    | running  | 35 MB  | –             |

- Oracle-Connect von Host: `sys/oracle@localhost:1521/XEPDB1`, App-User `app/app`.
- Postgres: `demo/demo` – DB `demo`.
- Ora2Pg ↔ Oracle-Verbindung getestet: `ora2pg -t SHOW_VERSION` liefert Oracle 21c.

### Beobachtungen / To-Do Infrastruktur

- `docker/oracle/init.sql` wird nicht ausgeführt – kein Mount nach `/container-entrypoint-initdb.d/`. Gleichzeitig legt das `gvenzl/oracle-xe`-Image bereits via `APP_USER=app` den App-User an; das init-Skript ist somit derzeit redundant/tot.
- Kein Healthcheck für Oracle → `depends_on` in `docker-compose.yml` startet `ora2pg` bevor Oracle bereit ist (unkritisch, weil ora2pg nur idle läuft, aber aufräumwürdig).
- Apple-Silicon-Thema: Oracle XE 21c gibt es nur als x86_64 → Rosetta. Alternativ: `container-registry.oracle.com/database/free:23.7.0.0-arm64` (Oracle 23ai Free, ARM64-nativ). Für eine Demo-Plattform deutlich ressourcenschonender. Einstieg jedoch mit XE sinnvoll (weiter verbreitet, mehr Doku).

### Nächste Schritte

1. Optional: `init.sql` via Volume-Mount an richtiger Stelle einhängen oder löschen.
2. Healthcheck + `depends_on: condition: service_healthy` ergänzen.
3. Demo-Schema in Oracle anlegen (Kunden/Bestellungen/Rechnungen) – Rolle DBA.
4. Ora2Pg-Config erweitern (Schema, Typ-Mapping, Exportverzeichnis).
5. Vollständiger Export + Import nach Postgres.
6. Validierung (Row-Counts, Stichproben, Constraints).

---

## 2026-04-17 – Docker-Cleanup & Demo-Schema APP_DEMO

### Änderungen an `docker-compose.yml`

- Oracle-Healthcheck aktiviert (`healthcheck.sh` aus dem gvenzl-Image, 30 s Intervall, 15 Retries, 60 s start_period).
- `ora2pg.depends_on` → `oracle: service_healthy`, `postgres: service_started`.
- Neuer Volume-Mount `./docker/oracle/init` → `/container-entrypoint-initdb.d` für automatische Schema-Initialisierung beim ersten DB-Start.

### Alte `init.sql` archiviert

- `docker/oracle/init.sql` → `docker/oracle/init.sql.old` (legte einen konkurrierenden `app_demo`-User mit anderem Schema an, kollidierte mit den neuen Init-Scripts).

### Demo-Schema APP_DEMO angelegt

Init-Scripts unter `docker/oracle/init/`:

- `01_users.sql` – User `app_demo/app_demo`, Privilegien inkl. `SELECT_CATALOG_ROLE` (für ora2pg).
- `02_schema.sql` – 3 Tabellen:
  - `KUNDEN` (ID IDENTITY, Adresse, EMAIL UNIQUE, CHECK aktiv)
  - `RECHNUNGEN` (ID IDENTITY, FK → KUNDEN, RECHNUNGSNUMMER UNIQUE, STATUS-CHECK, CLOB-Bemerkung)
  - `RECHNUNGSPOSITIONEN` (ID IDENTITY, FK → RECHNUNGEN mit ON DELETE CASCADE, UK auf rechnung_id+position)
  - Indizes auf allen FK-Spalten, Table-/Column-Comments.
- `03_data.sql` – 10 Kunden (DE/AT/CH), 15 Rechnungen, 20 Positionen. Mix aus OFFEN/BEZAHLT/MAHNUNG/STORNIERT und drei unterschiedlichen MwSt-Sätzen.
- `04_view.sql` – View `V_KUNDE_UMSATZ` (COUNT + konditionale SUM je Status).

### Oracle frisch aufgesetzt (Option A)

- `docker compose stop oracle ora2pg` → Daten-Verzeichnis `docker/oracle/data/` geleert (vorher 2,7 GB leere XE-Instanz) → `docker compose up -d oracle`.
- Erst-Init + alle 4 Scripts liefen sauber durch, DB meldete `healthy`.

### ora2pg.conf angepasst

- `ORACLE_USER=app_demo`, `ORACLE_PWD=app_demo`
- `SCHEMA APP_DEMO` gesetzt
- `OUTPUT_DIR /config/output` für spätere Export-Artefakte.

### Verifikation

| Objekt                | Soll | Ist |
| --------------------- | ---- | --- |
| Tabellen              | 3    | 3   |
| Views                 | 1    | 1   |
| Kunden-Zeilen         | 10   | 10  |
| Rechnungen-Zeilen     | 15   | 15  |
| Positionen-Zeilen     | 20   | 20  |

`ora2pg -t SHOW_TABLE -c ora2pg.conf` zeigt alle drei Tabellen unter Owner `APP_DEMO`.

### Nächste Schritte (Migration)

1. `ora2pg -t SHOW_REPORT --estimate_cost` für eine realistische Aufwandsschätzung.
2. Export der DDL: `ora2pg -t TABLE -o tables.sql` (+ VIEW, SEQUENCE falls nötig).
3. Daten-Export: `ora2pg -t COPY` direkt in die Postgres-DB `demo`.
4. Zielseitig Validierung (Row-Count-Diff, sampled Checksums).
5. Dokumentations-Run im Repo für Publishing.

---

## 2026-04-17 – Subagents aktiviert & Migration durchgeführt

### Subagents

- Vier echte Projekt-Subagents unter `.claude/agents/`: `infra.md`, `dba.md`, `migration.md`, `dev.md` mit YAML-Frontmatter und projektspezifischem System-Prompt.
- Alte Rollen-Beschreibungen nach `agents.archive/` verschoben (reversibel).
- Aktivierung greift ab nächster Claude-Code-Session automatisch.

### Migration Oracle → PostgreSQL

**ora2pg.conf ergänzt** um `PG_DSN`/`PG_USER`/`PG_PWD` und `PG_SCHEMA app_demo`.

**Analyse:** `ora2pg -t SHOW_REPORT --estimate_cost` meldete Level **B-4**, ~1 PT. Einzige flag: `CONCAT` in der View (harmlos, `||` existiert in Postgres identisch).

**DDL-Export** nach `migration/output/`:

- `tables.sql` – alle 3 Tabellen inkl. PK/UK/CHECK, Indexe, FK-Constraints. Ora2pg-Konvertierungen: `VARCHAR2` → `varchar`, `NUMBER(10,2)` → `decimal(10,2)`, `DATE` → `timestamp(0)`, `SYSDATE` → `statement_timestamp()`, `CLOB` → `text`, `IDENTITY` → `bigint GENERATED BY DEFAULT AS IDENTITY`.
- `views.sql` – `v_kunde_umsatz` mit `NVL` → `coalesce`.
- `AUTOINCREMENT_tables.sql` als Nebeneffekt (für Migrationen aus Trigger+Sequence-Patterns).

**Schema in Postgres** angelegt (`CREATE SCHEMA app_demo`, `ALTER ROLE demo SET search_path = app_demo, public`), DDL + View eingespielt.

**Daten-Import** via `ora2pg -t COPY`: 10+15+20=45 Zeilen in 1 Sekunde. Identity-Sequenzen manuell per `setval(pg_get_serial_sequence(...), MAX(id))` nachgezogen (Standard-Postmigration-Schritt).

**Validierung:**

| Check | Ergebnis |
| ----- | -------- |
| Row-Counts | ident. zu Oracle (10/15/20) |
| View `v_kunde_umsatz` Top-5 | identisch zu Oracle-Query |
| Neuer `INSERT kunden` | erzeugt ID 11 (Sequence ok) |
| Invalider Status | `ck_rechnung_status` blockt |
| Invalide FK | `fk_rechnung_kunde` blockt |

### Bekannte Stolperfallen (für Publishing wichtig)

- `docker exec` braucht `-i`, sobald stdin reingereicht wird (heredoc oder Redirect) – ohne `-i` liefert der Befehl lautlos „nichts".
- Nach `COPY` immer die Identity-Sequenzen mit `setval()` nachziehen.
- ora2pg „CONCAT"-Warnung in Views ist bei `||`-Verkettung ein False Positive.

### Offen / Nice-to-have

- Automatisierungs-Script (`migrate.sh`), das alle Schritte reproduzierbar kapselt.
- README im Projekt-Root mit Quickstart für Interessenten.
- Demo-API unter `api/` (Rolle: dev-Agent).

---

## 2026-04-17 – Publishing-Readiness

### `migrate.sh`

- One-Shot End-to-End-Script (8 Schritte, idempotent).
- Wipet das Postgres-Ziel-Schema bei jedem Lauf (Oracle bleibt unberührt).
- Smoke-Test: kompletter Durchlauf erfolgreich, Row-Counts und View-Sample matchen.

### `README.md`

- Architektur-Tabelle (amd64/arm64-Matrix), Quickstart, Client-Empfehlungen, Typ-Mapping-Tabelle, Reset-Hinweise, Stolperfallen.

### Status für Publishing

Minimal-Set ist beisammen: docker-compose, init-Scripts, ora2pg.conf, migrate.sh, README, Worklog, Subagents. Ein externer Interessent kann clonen → `docker compose up -d` → `./migrate.sh` und hat in ~3 Minuten ein lauffähiges Vorher/Nachher-Demo.

### Nächste natürliche Erweiterung

- `api/` Demo-Backend (z. B. FastAPI) gegen Postgres – zeigt, dass die migrierten Daten auch von Anwendungsseite direkt nutzbar sind.
- Zweites Demo-Projekt: gleiches Setup mit **Oracle 23ai Free ARM64** (native Apple Silicon, kein Rosetta).

---

## 2026-04-17 – FastAPI-Demo unter api/

### Umsetzung

- Single-File FastAPI (`api/main.py`), asyncpg-Pool mit `server_settings={"search_path": "app_demo, public"}`, 6 fachliche Endpoints + `/health`.
- Pydantic v2 Modelle: `KundeIn`/`Kunde`, `Rechnung`, `Position`, `RechnungDetail`, `Umsatz`.
- Dockerfile (python:3.12-slim), Compose-Service `api`, Port 8080→8000 (Port 8000 bereits von Portainer belegt → auf 8080 gemappt).

### Endpoints

| Methode | Pfad | Zweck |
| --- | --- | --- |
| GET | `/health` | DB-Ping |
| GET | `/kunden` | Liste, `limit`/`offset` |
| GET | `/kunden/{id}` | Detail, 404 wenn nicht vorhanden |
| GET | `/kunden/{id}/rechnungen` | Rechnungen eines Kunden, DESC sortiert |
| GET | `/rechnungen/{id}` | Rechnung + eingebettete Positionen |
| GET | `/umsatz` | View `v_kunde_umsatz` |
| POST | `/kunden` | Anlegen, 409 bei doppelter E-Mail |

### Smoke-Tests

- Alle GET-Endpoints liefern korrekte Payloads und stimmen mit DB-Samples überein.
- POST erzeugt ID 11 (Identity-Sequenz nach Migration korrekt gesetzt).
- Unique-Violation → HTTP 409.
- Nicht existierende Ressource → HTTP 404.
- Swagger-UI unter `/docs` erreichbar (HTTP 200).

### Stolperfallen

- Port 8000 lokal in Benutzung (Portainer) – Mapping auf Host-Port 8080 löst das, Container selbst bleibt auf 8000.
- asyncpg braucht `server_settings` für den search_path, weil Pool-Connections zurück in den Pool recycelt werden; `SET search_path` als Einzelbefehl greift nicht zuverlässig über die gesamte Pool-Lebensdauer.

---

## 2026-04-17 – rollback.sh

- `rollback.sh` angelegt (droppt `app_demo` in Postgres, Oracle bleibt).
- Smoke-Test: Schema sauber entfernt, `./migrate.sh` direkt danach wieder lauffähig.
- README im Abschnitt „Reset" um Rollback ergänzt.

---

## 2026-04-20 – Zwei-Stufen-Demo-Struktur (basic + advanced)

### Motivation

Das bestehende Demo war für einen Einstieg zu komplex (PL/SQL-Package, Patches). Für ein YouTube-Video und Consulting-Präsentationen wurde eine zweistufige Struktur eingeführt: erst die saubere Migration ohne Nacharbeit, dann die realistische Komplexität.

### Neue Repo-Struktur

```
OracleDemo/
├── docker-compose.yml       (erweitert: 2x ora2pg, 2x API)
├── basic/
│   ├── migrate.sh           (8 Schritte, kein Patch)
│   ├── rollback.sh
│   ├── migration/ora2pg.conf
│   └── api/                 (FastAPI, Port 8081)
├── advanced/
│   ├── migrate.sh           (10 Schritte, 1 Patch – bisheriger Inhalt)
│   ├── rollback.sh
│   ├── migration/ora2pg.conf
│   ├── migration/output/patches/
│   ├── api/                 (FastAPI, Port 8080)
│   └── docs/
└── docker/oracle/init/
    ├── 10_basic_users.sql   }
    ├── 11_basic_schema.sql  } app_basic_demo
    ├── 12_basic_data.sql    }
    ├── 20_adv_users.sql     }
    ├── 21_adv_schema.sql    }
    ├── 22_adv_data.sql      } app_demo (bisheriger Inhalt, umbenannt)
    ├── 23_adv_view.sql      }
    ├── 24_adv_triggers.sql  }
    └── 25_adv_package.sql   }
```

### Schema app_basic_demo

- `PRODUKTE` (ID IDENTITY, NAME, BESCHREIBUNG, PREIS NUMBER(10,2), LAGERBESTAND, ERSTELLT_AM DATE)
- `BESTELLUNGEN` (ID IDENTITY, FK → PRODUKTE, MENGE, BESTELLDATUM DATE, AKTUALISIERT_AM DATE)
- Index `IDX_PRODUKTE_NAME` auf `PRODUKTE(NAME)`
- Trigger `TRG_BESTELLUNG_UPDATE` – setzt `AKTUALISIERT_AM := SYSDATE` bei UPDATE
- 5 Produkte, 8 Bestellungen als Testdaten

Alle Oracle-Typen (VARCHAR2, NUMBER, DATE, SYSDATE, IDENTITY) wandern 1:1 via Ora2Pg — kein einziger manueller Patch.

### Neue Compose-Services

| Service | Container | Port | Mountpunkt |
|---|---|---|---|
| `ora2pg-basic` | `ora2pg-basic` | – | `./basic/migration:/config` |
| `ora2pg-advanced` | `ora2pg-advanced` | – | `./advanced/migration:/config` |
| `api-basic` | `oracledemo-api-basic` | 8081→8000 | `./basic/api` |
| `api-advanced` | `oracledemo-api-advanced` | 8080→8000 | `./advanced/api` |

### Workflow (wie vom User gewünscht)

Oracle-Container läuft, Migration per Script:
```bash
./basic/migrate.sh      # Basic-Demo, kein Patch
./advanced/migrate.sh   # Advanced-Demo, inkl. Patch
```

### Stolperfallen (neu entdeckt)

**Oracle-Init-Scripts brauchen `ALTER SESSION SET CONTAINER = XEPDB1` + `EXIT`.**
gvenzl/oracle-xe startet Init-Scripts als SYS im CDB-Kontext. Ohne explizites `ALTER SESSION SET CONTAINER = XEPDB1` landen GRANTs und Tabellen in CDB$ROOT, nicht in der PDB XEPDB1. User wird angelegt (sichtbar in `dba_users`), hat aber keinerlei Privilegien in der PDB. Alle drei Basic-Init-Scripts (`10_`, `11_`, `12_`) wurden um diesen Header ergänzt — die bestehenden Advanced-Scripts (`20_`–`25_`) hatten das korrekt bereits.

**Ora2Pg COPY: FK-Verletzung durch alphabetische Tabellenreihenfolge.**
`ora2pg -t COPY` kopiert Tabellen alphabetisch. Bei `BESTELLUNGEN` (vor `PRODUKTE`) schlägt der FK `fk_best_produkt` fehl, da `PRODUKTE` noch leer ist. Fix in `basic/migrate.sh`: `ALTER TABLE bestellungen DISABLE TRIGGER ALL` vor dem COPY-Lauf, danach `ENABLE`. In PostgreSQL sind FK-Constraints intern als Trigger implementiert — `DISABLE TRIGGER ALL` schaltet sie temporär aus.

**`DEFER_FKEY 1` funktioniert nicht mit Direct-Import.**
Ora2Pg kennt zwei Modi: File-Export (SQL-Datei) und Direct-Import (`PG_DSN` gesetzt → Ora2Pg verbindet selbst zu Postgres). `DEFER_FKEY 1` ist nur für File-Export gedacht und wird im Direct-Import mit Fehlermeldung abgelehnt.

**Orphan-Container blockieren Ports.**
Nach Service-Umbenennung in `docker-compose.yml` verbleiben alte Container (`oracledemo-api`, `ora2pg`) als Orphans. Diese belegen Ports (hier: 8080) und müssen explizit gestoppt/entfernt werden (`docker stop / docker rm`), bevor neue Services starten können.

### Ergebnis

| | Basic | Advanced |
|---|---|---|
| Tabellen | 2 | 3 + View |
| Patches | 0 | 1 |
| API-Port | 8081 | 8080 |
| Smoke-Test | 5+8 Zeilen ✓ | `kunde_umsatz(1) = 880.60` ✓ |
