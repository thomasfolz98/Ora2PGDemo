-- =============================================================
-- 04_view.sql
-- View fuer Kundenumsatz (ora2pg uebersetzt das nach PostgreSQL).
-- =============================================================

ALTER SESSION SET CONTAINER = XEPDB1;
ALTER SESSION SET CURRENT_SCHEMA = APP_DEMO;

CREATE OR REPLACE VIEW v_kunde_umsatz AS
SELECT k.id                                   AS kunden_id,
       k.vorname || ' ' || k.name             AS kundenname,
       k.land,
       COUNT(r.id)                            AS anzahl_rechnungen,
       NVL(SUM(CASE WHEN r.status = 'BEZAHLT'
                    THEN r.betrag_brutto END), 0) AS umsatz_bezahlt,
       NVL(SUM(CASE WHEN r.status = 'OFFEN'
                    THEN r.betrag_brutto END), 0) AS umsatz_offen
  FROM kunden     k
  LEFT JOIN rechnungen r ON r.kunden_id = k.id
 GROUP BY k.id, k.vorname, k.name, k.land;

COMMENT ON TABLE v_kunde_umsatz IS 'Aggregierte Umsaetze je Kunde, aufgeteilt nach Status';

EXIT;
