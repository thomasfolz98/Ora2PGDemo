-- =============================================================
-- 05_triggers.sql
-- Trigger fuer Audit (geaendert_am) und abgeleitete Felder (position_summe).
-- Laeuft nach 03_data.sql; deshalb am Ende ein Backfill-UPDATE, damit der
-- BEFORE-UPDATE-Trigger die bereits geladenen Positionen neu berechnet.
-- =============================================================

ALTER SESSION SET CONTAINER = XEPDB1;
ALTER SESSION SET CURRENT_SCHEMA = APP_DEMO;

-- ---------- Audit-Trigger auf RECHNUNGEN ----------
CREATE OR REPLACE TRIGGER trg_rechnungen_aud
BEFORE UPDATE ON rechnungen
FOR EACH ROW
BEGIN
    :NEW.geaendert_am := SYSTIMESTAMP;
END;
/

-- ---------- Summen-Trigger auf RECHNUNGSPOSITIONEN ----------
CREATE OR REPLACE TRIGGER trg_position_summe
BEFORE INSERT OR UPDATE ON rechnungspositionen
FOR EACH ROW
BEGIN
    :NEW.position_summe := :NEW.menge * :NEW.einzelpreis;
END;
/

-- Backfill: Positionen einmal "anfassen", damit der BEFORE-UPDATE-Trigger
-- position_summe fuer die bereits geladenen Daten befuellt.
UPDATE rechnungspositionen
   SET menge = menge;

COMMIT;

EXIT;
