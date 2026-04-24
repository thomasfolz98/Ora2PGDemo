-- --------------------------------------------------------------------
-- Patch 01: kunde_umsatz / berechne_rechnungssumme sollen numeric statt
-- bigint zurueckgeben, sonst rundet Postgres 880.60 auf 881.
--
-- Ora2Pg bildet Oracle NUMBER ohne Precision per Default auf bigint ab
-- (siehe DATA_TYPE in /etc/ora2pg/ora2pg.conf.dist). Damit geht die
-- Dezimalstelle aus Oracle verloren. Loesung: betroffene Funktionen mit
-- CREATE OR REPLACE ueberschreiben und Typen auf numeric ziehen.
-- --------------------------------------------------------------------

SET search_path = pkg_faktura, app_demo, public;

-- Postgres erlaubt kein CREATE OR REPLACE mit geaendertem Rueckgabetyp,
-- darum explizit droppen.
DROP FUNCTION IF EXISTS pkg_faktura.kunde_umsatz(bigint);
DROP FUNCTION IF EXISTS pkg_faktura.berechne_rechnungssumme(bigint);

CREATE OR REPLACE FUNCTION pkg_faktura.kunde_umsatz (p_kunde_id bigint)
RETURNS numeric
AS $body$
DECLARE
    v_summe numeric;
BEGIN
    RAISE NOTICE 'pkg_faktura.kunde_umsatz(%)', p_kunde_id;
    SELECT coalesce(SUM(betrag_brutto), 0)
      INTO STRICT v_summe
      FROM app_demo.rechnungen
     WHERE kunden_id = p_kunde_id
       AND status    = 'BEZAHLT';
    RETURN v_summe;
END;
$body$ LANGUAGE plpgsql SECURITY DEFINER;

CREATE OR REPLACE FUNCTION pkg_faktura.berechne_rechnungssumme (p_rechnung_id bigint)
RETURNS numeric
AS $body$
DECLARE
    v_summe numeric;
BEGIN
    RAISE NOTICE 'pkg_faktura.berechne_rechnungssumme(%)', p_rechnung_id;
    SELECT coalesce(SUM(position_summe), 0)
      INTO STRICT v_summe
      FROM app_demo.rechnungspositionen
     WHERE rechnung_id = p_rechnung_id;
    RETURN v_summe;
END;
$body$ LANGUAGE plpgsql SECURITY DEFINER;
