# Ora2Pg – Wichtigste Befehle

Alle Befehle werden im ora2pg-Container ausgeführt. Grundsyntax:

```bash
docker exec ora2pg bash -lc 'cd /config-advanced && ora2pg -t <TYP> -c ora2pg.conf -o <ausgabe.sql>'
```

---

## Analyse (vor der Migration)

| Befehl | Beschreibung |
|--------|-------------|
| `ora2pg -t SHOW_REPORT -c ora2pg.conf --dump_as_html > output/report.html` | Migrations-Assessment: Objektzählung, Cost Level A–E, geschätzter Aufwand in Manntagen. Kein SQL-Export — nur Analyse. |
| `ora2pg -t SHOW_TABLE -c ora2pg.conf` | Listet alle Tabellen im Source-Schema mit Zeilenzahl. Schnell-Check vor dem Export. |

## DDL-Export

| Befehl | Beschreibung |
|--------|-------------|
| `ora2pg -t TABLE -c ora2pg.conf -o tables.sql` | Exportiert DDL aller Tabellen (CREATE TABLE, Constraints, Indizes). Oracle-Typen werden automatisch auf PostgreSQL abgebildet (z.B. `VARCHAR2` → `varchar`, `NUMBER` → `numeric`/`bigint`). |
| `ora2pg -t SEQUENCE -c ora2pg.conf -o sequences.sql` | Exportiert Sequenzen. Bei IDENTITY-Columns wird zusätzlich `AUTOINCREMENT_tables.sql` erzeugt. |
| `ora2pg -t VIEW -c ora2pg.conf -o views.sql` | Exportiert Views als PostgreSQL-kompatible `CREATE VIEW`-Statements. |
| `ora2pg -t TRIGGER -c ora2pg.conf -o triggers.sql` | Exportiert Trigger — Oracle PL/SQL wird automatisch in PL/pgSQL übersetzt. |
| `ora2pg -t PACKAGE -c ora2pg.conf -o package.sql` | Exportiert PL/SQL-Packages. Mit `PACKAGE_AS_SCHEMA 1` in ora2pg.conf landet jedes Package in einem eigenen PostgreSQL-Schema. |
| `ora2pg -t FUNCTION -c ora2pg.conf -o functions.sql` | Exportiert einzelne Stored Functions (außerhalb von Packages). |
| `ora2pg -t PROCEDURE -c ora2pg.conf -o procedures.sql` | Exportiert einzelne Stored Procedures. |

## Datenmigration

| Befehl | Beschreibung |
|--------|-------------|
| `ora2pg -t COPY -c ora2pg.conf` | Kopiert Daten direkt Oracle → PostgreSQL (kein Zwischenspeichern, schnell). Tabellen werden alphabetisch verarbeitet — bei FK-Abhängigkeiten ggf. `DISABLE TRIGGER ALL` nötig (siehe `migrate.sh`). |
| `ora2pg -t INSERT -c ora2pg.conf -o data.sql` | Exportiert Daten als INSERT-Statements in eine SQL-Datei. Langsamer als COPY, aber portabler (z.B. für Debugging). |

---

## Hinweise

- `-c ora2pg.conf` — Konfigurationsdatei mit Verbindungsdaten, Schema, Typ-Mapping
- `-o <datei.sql>` — **Nur Export in Datei.** Der Import nach PostgreSQL erfolgt danach separat (z.B. via `psql -f tables.sql`). Ohne `-o` und mit gesetztem `PG_DSN` in ora2pg.conf importiert ora2pg direkt in PostgreSQL — so arbeitet `COPY` in diesem Projekt.
- `--dump_as_html` — Nur für `SHOW_REPORT`: erzeugt HTML statt Text
- Typ-Mapping (z.B. `NUMBER` → `bigint` vs. `numeric`) ist konfigurierbar über `DATA_TYPE` in ora2pg.conf — fehlerhaftes Mapping ist der häufigste Grund für manuelle Patches
