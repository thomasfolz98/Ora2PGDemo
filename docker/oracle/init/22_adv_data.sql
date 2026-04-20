-- =============================================================
-- 03_data.sql
-- Testdaten: 10 Kunden, 15 Rechnungen, 30 Positionen.
-- =============================================================

ALTER SESSION SET CONTAINER = XEPDB1;
ALTER SESSION SET CURRENT_SCHEMA = APP_DEMO;

-- ---------- KUNDEN ----------
INSERT INTO kunden (anrede, vorname, name, email, telefon, strasse, plz, ort, land) VALUES ('Herr', 'Max',     'Mustermann',  'max.mustermann@example.de',    '+49 30 1234567',  'Hauptstr. 1',     '10115', 'Berlin',    'DE');
INSERT INTO kunden (anrede, vorname, name, email, telefon, strasse, plz, ort, land) VALUES ('Frau', 'Erika',   'Musterfrau',  'erika.musterfrau@example.de',  '+49 40 7654321',  'Marktplatz 5',    '20095', 'Hamburg',   'DE');
INSERT INTO kunden (anrede, vorname, name, email, telefon, strasse, plz, ort, land) VALUES ('Herr', 'Hans',    'Schulze',     'hans.schulze@example.de',      '+49 89 4567890',  'Leopoldstr. 12',  '80802', 'Muenchen',  'DE');
INSERT INTO kunden (anrede, vorname, name, email, telefon, strasse, plz, ort, land) VALUES ('Frau', 'Anna',    'Schmidt',     'anna.schmidt@example.de',      '+49 221 987654',  'Domkloster 4',    '50667', 'Koeln',     'DE');
INSERT INTO kunden (anrede, vorname, name, email, telefon, strasse, plz, ort, land) VALUES ('Herr', 'Peter',   'Meier',       'peter.meier@example.de',       '+49 69 1122334',  'Zeil 100',        '60313', 'Frankfurt', 'DE');
INSERT INTO kunden (anrede, vorname, name, email, telefon, strasse, plz, ort, land) VALUES ('Frau', 'Julia',   'Weber',       'julia.weber@example.at',       '+43 1 5551234',   'Ringstr. 22',     '1010',  'Wien',      'AT');
INSERT INTO kunden (anrede, vorname, name, email, telefon, strasse, plz, ort, land) VALUES ('Herr', 'Thomas',  'Fischer',     'thomas.fischer@example.ch',    '+41 44 3334455',  'Bahnhofstr. 3',   '8001',  'Zuerich',   'CH');
INSERT INTO kunden (anrede, vorname, name, email, telefon, strasse, plz, ort, land) VALUES ('Frau', 'Laura',   'Becker',      'laura.becker@example.de',      '+49 351 998877',  'Pragerstr. 8',    '01069', 'Dresden',   'DE');
INSERT INTO kunden (anrede, vorname, name, email, telefon, strasse, plz, ort, land) VALUES ('Herr', 'Stefan',  'Hoffmann',    'stefan.hoffmann@example.de',   '+49 711 2233445', 'Koenigstr. 55',   '70173', 'Stuttgart', 'DE');
INSERT INTO kunden (anrede, vorname, name, email, telefon, strasse, plz, ort, land) VALUES ('Frau', 'Sabine',  'Wagner',      'sabine.wagner@example.de',     '+49 511 667788',  'Ernst-August-Pl. 1','30159','Hannover', 'DE');

-- ---------- RECHNUNGEN ----------
-- Hilfs-Muster: Bruttobetrag = netto * (1 + mwst/100), auf 2 Stellen gerundet.
INSERT INTO rechnungen (rechnungsnummer, kunden_id, rechnungsdatum, faellig_am, betrag_netto, mwst_satz, betrag_brutto, status, bemerkung) VALUES ('RE-2025-0001', 1, DATE '2025-11-03', DATE '2025-12-03',  420.00, 19.00,  499.80, 'BEZAHLT',  'Erstbestellung, Zahlung per Ueberweisung');
INSERT INTO rechnungen (rechnungsnummer, kunden_id, rechnungsdatum, faellig_am, betrag_netto, mwst_satz, betrag_brutto, status, bemerkung) VALUES ('RE-2025-0002', 2, DATE '2025-11-05', DATE '2025-12-05',  150.00, 19.00,  178.50, 'BEZAHLT',  NULL);
INSERT INTO rechnungen (rechnungsnummer, kunden_id, rechnungsdatum, faellig_am, betrag_netto, mwst_satz, betrag_brutto, status, bemerkung) VALUES ('RE-2025-0003', 3, DATE '2025-12-12', DATE '2026-01-11', 1280.00,  7.00, 1369.60, 'OFFEN',    'Buecherpaket - ermaessigter Steuersatz');
INSERT INTO rechnungen (rechnungsnummer, kunden_id, rechnungsdatum, faellig_am, betrag_netto, mwst_satz, betrag_brutto, status, bemerkung) VALUES ('RE-2025-0004', 4, DATE '2025-12-20', DATE '2026-01-19',   89.90, 19.00,  106.98, 'BEZAHLT',  NULL);
INSERT INTO rechnungen (rechnungsnummer, kunden_id, rechnungsdatum, faellig_am, betrag_netto, mwst_satz, betrag_brutto, status, bemerkung) VALUES ('RE-2026-0001', 5, DATE '2026-01-10', DATE '2026-02-09', 2450.00, 19.00, 2915.50, 'OFFEN',    'Grossauftrag Q1');
INSERT INTO rechnungen (rechnungsnummer, kunden_id, rechnungsdatum, faellig_am, betrag_netto, mwst_satz, betrag_brutto, status, bemerkung) VALUES ('RE-2026-0002', 1, DATE '2026-01-15', DATE '2026-02-14',  320.00, 19.00,  380.80, 'BEZAHLT',  NULL);
INSERT INTO rechnungen (rechnungsnummer, kunden_id, rechnungsdatum, faellig_am, betrag_netto, mwst_satz, betrag_brutto, status, bemerkung) VALUES ('RE-2026-0003', 6, DATE '2026-01-22', DATE '2026-02-21',  999.00, 20.00, 1198.80, 'BEZAHLT',  'Kunde AT - 20% Ust.');
INSERT INTO rechnungen (rechnungsnummer, kunden_id, rechnungsdatum, faellig_am, betrag_netto, mwst_satz, betrag_brutto, status, bemerkung) VALUES ('RE-2026-0004', 7, DATE '2026-02-01', DATE '2026-03-03',  550.00,  7.70,  592.35, 'OFFEN',    'Kunde CH - 7.7% MWST');
INSERT INTO rechnungen (rechnungsnummer, kunden_id, rechnungsdatum, faellig_am, betrag_netto, mwst_satz, betrag_brutto, status, bemerkung) VALUES ('RE-2026-0005', 8, DATE '2026-02-14', DATE '2026-03-16',  210.00, 19.00,  249.90, 'MAHNUNG',  '1. Mahnung verschickt 2026-04-02');
INSERT INTO rechnungen (rechnungsnummer, kunden_id, rechnungsdatum, faellig_am, betrag_netto, mwst_satz, betrag_brutto, status, bemerkung) VALUES ('RE-2026-0006', 9, DATE '2026-02-28', DATE '2026-03-30',  780.00, 19.00,  928.20, 'BEZAHLT',  NULL);
INSERT INTO rechnungen (rechnungsnummer, kunden_id, rechnungsdatum, faellig_am, betrag_netto, mwst_satz, betrag_brutto, status, bemerkung) VALUES ('RE-2026-0007',10, DATE '2026-03-05', DATE '2026-04-04',  120.00, 19.00,  142.80, 'STORNIERT','Kunde hat widerrufen');
INSERT INTO rechnungen (rechnungsnummer, kunden_id, rechnungsdatum, faellig_am, betrag_netto, mwst_satz, betrag_brutto, status, bemerkung) VALUES ('RE-2026-0008', 2, DATE '2026-03-11', DATE '2026-04-10',  445.00, 19.00,  529.55, 'OFFEN',    NULL);
INSERT INTO rechnungen (rechnungsnummer, kunden_id, rechnungsdatum, faellig_am, betrag_netto, mwst_satz, betrag_brutto, status, bemerkung) VALUES ('RE-2026-0009', 3, DATE '2026-03-18', DATE '2026-04-17',   65.00, 19.00,   77.35, 'BEZAHLT',  NULL);
INSERT INTO rechnungen (rechnungsnummer, kunden_id, rechnungsdatum, faellig_am, betrag_netto, mwst_satz, betrag_brutto, status, bemerkung) VALUES ('RE-2026-0010', 5, DATE '2026-04-01', DATE '2026-05-01', 1750.00, 19.00, 2082.50, 'OFFEN',    'Folgeauftrag aus RE-2026-0001');
INSERT INTO rechnungen (rechnungsnummer, kunden_id, rechnungsdatum, faellig_am, betrag_netto, mwst_satz, betrag_brutto, status, bemerkung) VALUES ('RE-2026-0011', 4, DATE '2026-04-15', DATE '2026-05-15',  299.00, 19.00,  355.81, 'OFFEN',    NULL);

-- ---------- POSITIONEN ----------
INSERT INTO rechnungspositionen (rechnung_id, position, beschreibung, menge, einheit, einzelpreis, gesamtpreis) VALUES (1, 1, 'Beratung Projekt Aufsatz',  4,   'Std',  90.00,  360.00);
INSERT INTO rechnungspositionen (rechnung_id, position, beschreibung, menge, einheit, einzelpreis, gesamtpreis) VALUES (1, 2, 'Reisekostenpauschale',      1,   'Stk',  60.00,   60.00);
INSERT INTO rechnungspositionen (rechnung_id, position, beschreibung, menge, einheit, einzelpreis, gesamtpreis) VALUES (2, 1, 'Lizenz ''DemoTool'' Jahresabo',1,'Stk', 150.00,  150.00);
INSERT INTO rechnungspositionen (rechnung_id, position, beschreibung, menge, einheit, einzelpreis, gesamtpreis) VALUES (3, 1, 'Fachbuch Oracle Administration', 8, 'Stk',  49.00,  392.00);
INSERT INTO rechnungspositionen (rechnung_id, position, beschreibung, menge, einheit, einzelpreis, gesamtpreis) VALUES (3, 2, 'Fachbuch PostgreSQL Internals',  6, 'Stk',  55.00,  330.00);
INSERT INTO rechnungspositionen (rechnung_id, position, beschreibung, menge, einheit, einzelpreis, gesamtpreis) VALUES (3, 3, 'Fachbuch Migration Patterns',   11, 'Stk',  50.73,  558.00);
INSERT INTO rechnungspositionen (rechnung_id, position, beschreibung, menge, einheit, einzelpreis, gesamtpreis) VALUES (4, 1, 'USB-C Hub 7-in-1',               1, 'Stk',  89.90,   89.90);
INSERT INTO rechnungspositionen (rechnung_id, position, beschreibung, menge, einheit, einzelpreis, gesamtpreis) VALUES (5, 1, 'Workshop Data Migration (Tag 1)',1, 'Tag', 1250.00,1250.00);
INSERT INTO rechnungspositionen (rechnung_id, position, beschreibung, menge, einheit, einzelpreis, gesamtpreis) VALUES (5, 2, 'Workshop Data Migration (Tag 2)',1, 'Tag', 1200.00,1200.00);
INSERT INTO rechnungspositionen (rechnung_id, position, beschreibung, menge, einheit, einzelpreis, gesamtpreis) VALUES (6, 1, 'Support-Stunden',                4, 'Std',  80.00,  320.00);
INSERT INTO rechnungspositionen (rechnung_id, position, beschreibung, menge, einheit, einzelpreis, gesamtpreis) VALUES (7, 1, 'Sonderanfertigung Logo-Design',  1, 'Stk', 999.00,  999.00);
INSERT INTO rechnungspositionen (rechnung_id, position, beschreibung, menge, einheit, einzelpreis, gesamtpreis) VALUES (8, 1, 'IT-Audit vor Ort (halber Tag)',  1, 'Pau', 550.00,  550.00);
INSERT INTO rechnungspositionen (rechnung_id, position, beschreibung, menge, einheit, einzelpreis, gesamtpreis) VALUES (9, 1, 'Schulung Oracle Basics',         3, 'Std',  70.00,  210.00);
INSERT INTO rechnungspositionen (rechnung_id, position, beschreibung, menge, einheit, einzelpreis, gesamtpreis) VALUES (10,1, 'Monatsbeitrag Managed Service',  1, 'Mon', 780.00,  780.00);
INSERT INTO rechnungspositionen (rechnung_id, position, beschreibung, menge, einheit, einzelpreis, gesamtpreis) VALUES (11,1, 'Headset Premium',                1, 'Stk', 120.00,  120.00);
INSERT INTO rechnungspositionen (rechnung_id, position, beschreibung, menge, einheit, einzelpreis, gesamtpreis) VALUES (12,1, 'Consulting Data Warehouse',      5, 'Std',  89.00,  445.00);
INSERT INTO rechnungspositionen (rechnung_id, position, beschreibung, menge, einheit, einzelpreis, gesamtpreis) VALUES (13,1, 'Kleinbeauftragung (Pauschale)',  1, 'Pau',  65.00,   65.00);
INSERT INTO rechnungspositionen (rechnung_id, position, beschreibung, menge, einheit, einzelpreis, gesamtpreis) VALUES (14,1, 'Cloud-Migration Phase 1',        1, 'Pau', 950.00,  950.00);
INSERT INTO rechnungspositionen (rechnung_id, position, beschreibung, menge, einheit, einzelpreis, gesamtpreis) VALUES (14,2, 'Cloud-Migration Phase 2',        1, 'Pau', 800.00,  800.00);
INSERT INTO rechnungspositionen (rechnung_id, position, beschreibung, menge, einheit, einzelpreis, gesamtpreis) VALUES (15,1, 'Web-Relaunch Paket',             1, 'Pau', 299.00,  299.00);

COMMIT;

EXIT;
