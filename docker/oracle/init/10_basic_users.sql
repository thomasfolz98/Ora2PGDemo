-- app_basic_demo: Demo-User fuer die einfache Migrations-Demo (ohne Nacharbeit)
-- Wird von gvenzl/oracle-xe beim ersten DB-Start als SYS im CDB-Kontext ausgefuehrt.

ALTER SESSION SET CONTAINER = XEPDB1;

CREATE USER app_basic_demo IDENTIFIED BY app_basic_demo
  DEFAULT TABLESPACE users
  TEMPORARY TABLESPACE temp
  QUOTA UNLIMITED ON users;

GRANT CREATE SESSION,
      CREATE TABLE,
      CREATE SEQUENCE,
      CREATE TRIGGER
  TO app_basic_demo;

GRANT SELECT_CATALOG_ROLE TO app_basic_demo;

EXIT;
