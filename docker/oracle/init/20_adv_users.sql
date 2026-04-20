-- =============================================================
-- 01_users.sql
-- Legt den Demo-Schema-User APP_DEMO in der PDB XEPDB1 an.
-- Wird von gvenzl/oracle-xe beim ersten DB-Start als SYS ausgefuehrt.
-- =============================================================

ALTER SESSION SET CONTAINER = XEPDB1;

CREATE USER app_demo IDENTIFIED BY app_demo
    DEFAULT TABLESPACE USERS
    TEMPORARY TABLESPACE TEMP
    QUOTA UNLIMITED ON USERS;

GRANT CREATE SESSION,
      CREATE TABLE,
      CREATE VIEW,
      CREATE SEQUENCE,
      CREATE PROCEDURE,
      CREATE TRIGGER,
      CREATE SYNONYM
  TO app_demo;

-- Lese-Rechte fuer ora2pg (liest Dictionary-Views)
GRANT SELECT_CATALOG_ROLE TO app_demo;

EXIT;
