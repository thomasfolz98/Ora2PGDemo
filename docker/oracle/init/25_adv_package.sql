-- =============================================================
-- 06_package.sql
-- PL/SQL-Package PKG_FAKTURA - kleine Fachlogik fuer den Migrations-Demo.
-- Bewusst "klassisches" PL/SQL ohne autonome Transaktionen o.a.,
-- damit ora2pg das spaeter moeglichst sauber nach PL/pgSQL uebersetzt.
-- =============================================================

ALTER SESSION SET CONTAINER = XEPDB1;
ALTER SESSION SET CURRENT_SCHEMA = APP_DEMO;

-- ---------- Spec ----------
CREATE OR REPLACE PACKAGE pkg_faktura AS
    e_kunde_nicht_gefunden    EXCEPTION;
    e_rechnung_nicht_gefunden EXCEPTION;
    e_ungueltiger_status      EXCEPTION;

    FUNCTION  get_kunde              (p_id IN NUMBER) RETURN kunden%ROWTYPE;
    FUNCTION  kunde_umsatz           (p_kunde_id IN NUMBER) RETURN NUMBER;
    FUNCTION  berechne_rechnungssumme(p_rechnung_id IN NUMBER) RETURN NUMBER;
    PROCEDURE erstelle_kunde         (p_vorname IN VARCHAR2,
                                      p_name    IN VARCHAR2,
                                      p_email   IN VARCHAR2,
                                      p_id      OUT NUMBER);
    PROCEDURE setze_rechnungs_status (p_rechnung_id IN NUMBER,
                                      p_status      IN VARCHAR2);
END pkg_faktura;
/

-- ---------- Body ----------
CREATE OR REPLACE PACKAGE BODY pkg_faktura AS

    --------------------------------------------------------------
    FUNCTION get_kunde (p_id IN NUMBER)
        RETURN kunden%ROWTYPE
    IS
        v_row kunden%ROWTYPE;
    BEGIN
        DBMS_OUTPUT.PUT_LINE('pkg_faktura.get_kunde(' || p_id || ')');
        SELECT *
          INTO v_row
          FROM kunden
         WHERE id = p_id;
        RETURN v_row;
    EXCEPTION
        WHEN NO_DATA_FOUND THEN
            DBMS_OUTPUT.PUT_LINE('  -> Kunde nicht gefunden');
            RAISE e_kunde_nicht_gefunden;
    END get_kunde;

    --------------------------------------------------------------
    FUNCTION kunde_umsatz (p_kunde_id IN NUMBER)
        RETURN NUMBER
    IS
        v_summe NUMBER;
    BEGIN
        DBMS_OUTPUT.PUT_LINE('pkg_faktura.kunde_umsatz(' || p_kunde_id || ')');
        SELECT NVL(SUM(betrag_brutto), 0)
          INTO v_summe
          FROM rechnungen
         WHERE kunden_id = p_kunde_id
           AND status    = 'BEZAHLT';
        RETURN v_summe;
    END kunde_umsatz;

    --------------------------------------------------------------
    FUNCTION berechne_rechnungssumme (p_rechnung_id IN NUMBER)
        RETURN NUMBER
    IS
        v_summe NUMBER;
    BEGIN
        DBMS_OUTPUT.PUT_LINE('pkg_faktura.berechne_rechnungssumme('
                             || p_rechnung_id || ')');
        SELECT NVL(SUM(position_summe), 0)
          INTO v_summe
          FROM rechnungspositionen
         WHERE rechnung_id = p_rechnung_id;
        RETURN v_summe;
    END berechne_rechnungssumme;

    --------------------------------------------------------------
    PROCEDURE erstelle_kunde (p_vorname IN VARCHAR2,
                              p_name    IN VARCHAR2,
                              p_email   IN VARCHAR2,
                              p_id      OUT NUMBER)
    IS
    BEGIN
        DBMS_OUTPUT.PUT_LINE('pkg_faktura.erstelle_kunde(' || p_email || ')');
        INSERT INTO kunden (vorname, name, email)
             VALUES (p_vorname, p_name, p_email)
          RETURNING id INTO p_id;
        DBMS_OUTPUT.PUT_LINE('  -> neue Kunden-ID = ' || p_id);
    END erstelle_kunde;

    --------------------------------------------------------------
    PROCEDURE setze_rechnungs_status (p_rechnung_id IN NUMBER,
                                      p_status      IN VARCHAR2)
    IS
        v_count NUMBER;
    BEGIN
        DBMS_OUTPUT.PUT_LINE('pkg_faktura.setze_rechnungs_status('
                             || p_rechnung_id || ', ' || p_status || ')');

        IF p_status NOT IN ('OFFEN','BEZAHLT','MAHNUNG','STORNIERT') THEN
            DBMS_OUTPUT.PUT_LINE('  -> ungueltiger Status');
            RAISE e_ungueltiger_status;
        END IF;

        UPDATE rechnungen
           SET status = p_status
         WHERE id = p_rechnung_id;

        v_count := SQL%ROWCOUNT;
        IF v_count = 0 THEN
            DBMS_OUTPUT.PUT_LINE('  -> Rechnung nicht gefunden');
            RAISE e_rechnung_nicht_gefunden;
        END IF;

        DBMS_OUTPUT.PUT_LINE('  -> ' || v_count || ' Zeile(n) aktualisiert');
    END setze_rechnungs_status;

END pkg_faktura;
/

EXIT;
