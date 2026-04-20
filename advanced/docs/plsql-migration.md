# PL/SQL-Migration nach PostgreSQL – Best Practices mit Ora2Pg

Kompaktes Nachschlagewerk zu den nicht-trivialen Teilen einer
Oracle-nach-PostgreSQL-Migration: Prozeduren, Funktionen, Trigger und
PL/SQL-Packages. Komplementär zur [README](../README.md) und zum
[Worklog](../Worklog.md) des OracleDemo-Projekts.

## Was Ora2Pg automatisch konvertiert

| Oracle                       | Ora2Pg-Export-Typ  | PostgreSQL-Ziel                          |
| ---------------------------- | ------------------ | ---------------------------------------- |
| `FUNCTION`                   | `FUNCTION`         | `FUNCTION` (plpgsql)                     |
| `PROCEDURE`                  | `PROCEDURE`        | `PROCEDURE` (PG ≥ 11) oder Void-Function |
| `TRIGGER`                    | `TRIGGER`          | Trigger-Function + `CREATE TRIGGER`      |
| `PACKAGE` / `PACKAGE BODY`   | `PACKAGE`          | **Schema** pro Package, Funktionen als Members |
| Package-Variablen            | –                  | kein direktes Äquivalent (siehe unten)   |
| `TYPE` (Object, VARRAY)      | `TYPE`             | composite type / array                   |
| `SEQUENCE`                   | `SEQUENCE`         | `SEQUENCE`                               |

## Cost Assessment zuerst

Ora2Pg berechnet pro Objekt einen Migrations-Aufwand:

```bash
docker exec ora2pg bash -lc 'cd /config && ora2pg -t SHOW_REPORT --estimate_cost -c ora2pg.conf'
```

Für einen teilbaren Report:

```bash
docker exec ora2pg bash -lc 'cd /config && ora2pg -t SHOW_REPORT --estimate_cost --dump_as_html -c ora2pg.conf' > migration/report.html
```

Migration Levels:
- **A** – vollautomatisch möglich
- **B** – Code-Rewrite, bis zu 5 PT
- **C** – Code-Rewrite, mehr als 5 PT

Technische Level 1–5 beschreiben wie tief das PL/SQL-Rewrite wird.
**Ab einem Pro-Objekt-Score von ~10 Punkten wird's Handarbeit** – diese
Zahlen sind die Grundlage für seriöse Aufwandsschätzungen beim Kunden.

## Best Practices

### 1. Stufen-Strategie – nie alles in einem Rutsch

Empfohlene Reihenfolge:

```
TABLE → SEQUENCE → INDEX → VIEW → TYPE
      → FUNCTION → PROCEDURE → TRIGGER → PACKAGE → GRANT
```

So hast du pro Stufe einen klaren "läuft durch / läuft nicht"-Commit und
kannst bei Problemen gezielt zurücksetzen, statt das ganze Schema neu zu
migrieren.

### 2. Packages als Schemas denken

Ora2Pg übersetzt `PKG_ORDERS.PROCESS_ORDER` nach **Schema** `pkg_orders`,
Funktion `process_order()`. Der Aufruf aus Anwendungscode bleibt
strukturell ähnlich (`pkg_orders.process_order(...)`), aber:

**Package-Variablen** (`g_last_id`, `g_user`) gibt es in Postgres nicht.
Optionen:

- **GUCs** (Grand Unified Configuration) für session-scoped State:
  ```sql
  SET app.last_id = '42';
  SELECT current_setting('app.last_id');
  ```
- **`UNLOGGED` Tabellen** für strukturierten State.
- **Application-Side verlagern** – oft die sauberste Lösung.

### 3. Autonome Transaktionen neu designen

`PRAGMA AUTONOMOUS_TRANSACTION` hat Postgres nicht. Übliche Wege:

- **`dblink`-Self-Call** (klassischer Trick, aber Overhead).
- **Background-Worker / pg_background** Extension.
- **Logik zur Anwendungsschicht hochziehen** – meist die robusteste
  Lösung und zwingt zu einer sauberen Schnittstelle.

Nie 1:1 übernehmen – die Semantik stimmt nicht.

### 4. Trigger kritisch prüfen

| Oracle                | PostgreSQL                                        |
| --------------------- | ------------------------------------------------- |
| `:NEW.col`, `:OLD.col`| `NEW.col`, `OLD.col` (ohne Doppelpunkt)           |
| `INSTEAD OF` auf View | unterstützt, aber Syntax anders                   |
| `COMPOUND TRIGGER`    | **nicht** vorhanden – in Phasen-Trigger auftrennen|
| `FOLLOWS`/`PRECEDES`  | nicht vorhanden – Reihenfolge über Namensschema   |

### 5. Exception-Handling

Oracles `WHEN OTHERS THEN` → Postgres `EXCEPTION WHEN OTHERS`. Ora2Pg
übersetzt Basis-Muster, aber:

- `SQLCODE` / `SQLERRM` vs. Postgres `GET STACKED DIAGNOSTICS` – **immer
  manuell nachprüfen**.
- Oracle named exceptions (`NO_DATA_FOUND`, `DUP_VAL_ON_INDEX`, …) haben
  in Postgres andere Namen (`NO_DATA_FOUND` existiert, `unique_violation`
  statt `DUP_VAL_ON_INDEX`).

### 6. Test-Harness vor dem Go-Live

Minimum-Setup:

- **[pgTAP](https://pgtap.org/)** oder einfache SQL-Assertions in beiden
  DBs parallel.
- Pro migrierte Funktion: identische Eingabe → identisches Ergebnis.
- Mit **realen** (oder zumindest echt geformten) Daten, nicht nur
  Happy-Path-Samples.

Ohne Test-Harness verlässt du dich auf "kompiliert ohne Fehler" – das ist
für eine Datenbank-Migration zu wenig.

### 7. Oracle-spezifische Built-ins mappen

| Oracle                            | PostgreSQL                              |
| --------------------------------- | --------------------------------------- |
| `NVL(x, y)`                       | `COALESCE(x, y)`                        |
| `DECODE(x, a, b, c, d, e)`        | `CASE WHEN x=a THEN b WHEN x=c THEN d ELSE e END` |
| `SYSDATE`                         | `statement_timestamp()` / `now()`       |
| `SYSTIMESTAMP`                    | `clock_timestamp()`                     |
| `ROWNUM`                          | `LIMIT` / `ROW_NUMBER() OVER (...)`     |
| `CONNECT BY PRIOR`                | Recursive CTE (`WITH RECURSIVE`)        |
| `DBMS_OUTPUT.PUT_LINE`            | `RAISE NOTICE`                          |
| `TO_CHAR(d, 'YYYY-MM-DD')`        | `to_char(d, 'YYYY-MM-DD')` (ähnlich)    |
| `||` (String-Concat)              | `||` (identisch)                        |
| `NVL2(a, b, c)`                   | `CASE WHEN a IS NOT NULL THEN b ELSE c END` |
| `MOD(x, y)`                       | `x % y`                                 |

Ora2Pg macht vieles davon automatisch, **nicht alles** – Ergebnis
immer reviewen.

### 8. `%TYPE` und `%ROWTYPE` beibehalten

Postgres unterstützt beide. Nicht umbauen – spart Wartungs­aufwand und
erhält die Kopplung an die Spaltendefinition.

### 9. DATE-Semantik beachten

Oracle `DATE` speichert **inklusive Uhrzeit** (bis Sekunde). Postgres
`date` speichert **nur das Datum**. Ora2Pg migriert Oracle-`DATE` daher
standardmäßig nach Postgres `timestamp(0)` – das ist korrekt, aber wenn
Anwendungscode bewusst `date`-Arithmetik macht, Review nötig.

### 10. Beide Seiten versionieren

Ora2Pg ist deterministisch genug, dass Re-Runs reproduzierbare Outputs
liefern. Nutze das:

- Oracle-Quelle ins Git.
- Ora2Pg-Output (`migration/output/`) ins Git.
- Diffs bei Konfig-Änderungen sind dann aussagekräftig im Code-Review.

## Was Ora2Pg *nicht* gut kann

Ehrliche Erwartungshaltung für Kundengespräche:

- **Object Types mit Methoden** – wird als composite type exportiert,
  Methoden verlierst du (manuell nachbauen).
- **DBMS_*-Packages** – nur Teilmenge (`DBMS_OUTPUT`, teilweise
  `DBMS_LOB`); vieles gibt's schlicht nicht in Postgres.
- **Fine-Grained Access Control (VPD, FGAC)** – Konzept ist nicht 1:1
  übertragbar, Postgres nutzt RLS (Row-Level Security).
- **Materialized Views mit FAST REFRESH** – Postgres kennt nur kompletten
  Refresh oder `REFRESH MATERIALIZED VIEW CONCURRENTLY`.
- **Oracle Text, Oracle Spatial** – Gegenstücke (`pg_trgm`/FTS, PostGIS)
  haben andere Syntax und Semantik.

## Ressourcen

### Ora2Pg

- [Offizielle Doku von Gilles Darold](https://ora2pg.darold.net/documentation.html)
  – Autor, Referenz-Qualität
- [Ora2Pg Start Guide](https://ora2pg.darold.net/start.html)
- [Microsoft Learn: Oracle → Azure PostgreSQL mit Ora2Pg](https://learn.microsoft.com/en-us/azure/postgresql/migrate/how-to-migrate-oracle-ora2pg)
  – praxisnaher End-to-End-Guide
- [Crunchy Data Blog: Setup Ora2Pg](https://www.crunchydata.com/blog/setup-ora2pg-for-oracle-to-postgres-migration)
- [Medium-Serie (Jeyaram Ayyalusamy, 2025)](https://medium.com/@jramcloud1/oracle-to-postgresql-migration-using-ora2pg-full-step-by-step-walkthrough-bc38760190df)
  – mehrteilig, Ora2Pg v25
- [Sirius Open Source: Ora2Pg-Migration](https://www.siriusopensource.com/en-us/blog/oracle-postgresql-migration-using-ora2pg)
- [Quest Blog: Near-Zero Downtime mit SharePlex + Ora2Pg](https://blog.quest.com/product-post/migrating-from-oracle-to-postgresql-with-near-zero-downtime-using-shareplex-and-ora2pg-131524679/)
- [Hevo: Complete Guide Oracle → PostgreSQL](https://hevodata.com/learn/complete-guide-on-oracle-to-postgresql-migration/)
- YouTube: Kanal **Learnomate Technologies** (@learnomate)

### PostgreSQL-Einstieg

- [FreeCodeCamp PostgreSQL Course](https://www.freecodecamp.org/news/posgresql-course-for-beginners/)
  – ~3 h YouTube-Crashkurs
- [pgtutorial.com](https://www.pgtutorial.com/) – strukturiertes
  Selbststudium mit Übungen
- [Neon PostgreSQL Tutorial](https://neon.com/postgresql/tutorial)
- [PostgreSQL Official Online Resources](https://www.postgresql.org/docs/online-resources/)
- [pgTAP – Unit Testing für PostgreSQL](https://pgtap.org/)
