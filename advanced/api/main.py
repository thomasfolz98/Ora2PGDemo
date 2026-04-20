"""
OracleDemo API – Demo-Backend fuer das migrierte Schema app_demo in PostgreSQL.

Endpoints (Auto-Docs unter /docs):
  GET  /health
  GET  /kunden
  GET  /kunden/{id}
  GET  /kunden/{id}/rechnungen
  GET  /kunden/{id}/umsatz          -> ruft migrierte pkg_faktura.kunde_umsatz
  GET  /rechnungen/{id}
  GET  /rechnungen/{id}/summe       -> ruft migrierte pkg_faktura.berechne_rechnungssumme
  GET  /umsatz
  POST /kunden
"""

from contextlib import asynccontextmanager
from datetime import datetime
from decimal import Decimal
from typing import List, Optional
import os

import asyncpg
from fastapi import FastAPI, HTTPException
from pydantic import BaseModel, Field

DB_DSN = os.getenv("DB_DSN", "postgresql://demo:demo@postgres:5432/demo")


# ---------- Lifespan: asyncpg-Pool ----------
@asynccontextmanager
async def lifespan(app: FastAPI):
    app.state.pool = await asyncpg.create_pool(
        DB_DSN,
        min_size=1,
        max_size=5,
        server_settings={"search_path": "app_demo, public"},
    )
    yield
    await app.state.pool.close()


app = FastAPI(
    title="OracleDemo API",
    description="Demo-Backend fuer das migrierte Schema app_demo in PostgreSQL.",
    version="1.0.0",
    lifespan=lifespan,
)


# ---------- Pydantic-Modelle ----------
class KundeIn(BaseModel):
    anrede: Optional[str] = Field(None, max_length=10)
    vorname: str = Field(..., max_length=50)
    name: str = Field(..., max_length=50)
    email: str = Field(..., max_length=100)
    telefon: Optional[str] = Field(None, max_length=30)
    strasse: Optional[str] = Field(None, max_length=100)
    plz: Optional[str] = Field(None, max_length=10)
    ort: Optional[str] = Field(None, max_length=60)
    land: str = Field("DE", max_length=2)


class Kunde(KundeIn):
    id: int
    erstellt_am: datetime
    aktiv: int


class Rechnung(BaseModel):
    id: int
    rechnungsnummer: str
    kunden_id: int
    rechnungsdatum: datetime
    faellig_am: Optional[datetime]
    betrag_netto: Decimal
    mwst_satz: Decimal
    betrag_brutto: Decimal
    status: str
    bemerkung: Optional[str]


class Position(BaseModel):
    id: int
    position: int
    beschreibung: str
    menge: Decimal
    einheit: str
    einzelpreis: Decimal
    gesamtpreis: Decimal


class RechnungDetail(Rechnung):
    positionen: List[Position]


class Umsatz(BaseModel):
    kunden_id: int
    kundenname: str
    land: str
    anzahl_rechnungen: int
    umsatz_bezahlt: Decimal
    umsatz_offen: Decimal


class KundeUmsatz(BaseModel):
    kunde_id: int
    umsatz: Decimal


class RechnungSumme(BaseModel):
    rechnung_id: int
    summe: Decimal


# ---------- Endpoints ----------
@app.get("/health", tags=["meta"])
async def health():
    async with app.state.pool.acquire() as c:
        await c.execute("SELECT 1")
    return {"status": "ok"}


@app.get("/kunden", response_model=List[Kunde], tags=["kunden"])
async def list_kunden(limit: int = 50, offset: int = 0):
    async with app.state.pool.acquire() as c:
        rows = await c.fetch(
            "SELECT * FROM app_demo.kunden ORDER BY id LIMIT $1 OFFSET $2",
            limit, offset,
        )
    return [dict(r) for r in rows]


@app.get("/kunden/{kunde_id}", response_model=Kunde, tags=["kunden"])
async def get_kunde(kunde_id: int):
    async with app.state.pool.acquire() as c:
        row = await c.fetchrow(
            "SELECT * FROM app_demo.kunden WHERE id=$1", kunde_id
        )
    if not row:
        raise HTTPException(404, f"Kunde {kunde_id} nicht gefunden")
    return dict(row)


@app.get(
    "/kunden/{kunde_id}/rechnungen",
    response_model=List[Rechnung],
    tags=["kunden"],
)
async def kunden_rechnungen(kunde_id: int):
    async with app.state.pool.acquire() as c:
        rows = await c.fetch(
            """SELECT * FROM app_demo.rechnungen
               WHERE kunden_id=$1
               ORDER BY rechnungsdatum DESC, id DESC""",
            kunde_id,
        )
    return [dict(r) for r in rows]


@app.get(
    "/kunden/{kunde_id}/umsatz",
    response_model=KundeUmsatz,
    tags=["kunden"],
)
async def kunde_umsatz(kunde_id: int):
    """Ruft die migrierte PL/pgSQL-Funktion pkg_faktura.kunde_umsatz auf.

    Demonstriert, dass die aus Oracle-PL/SQL portierte Package-Logik
    unveraendert aus der App heraus nutzbar ist.
    """
    async with app.state.pool.acquire() as c:
        # Existenz-Check: liefert 404, bevor die Funktion aufgerufen wird
        exists = await c.fetchval(
            "SELECT 1 FROM app_demo.kunden WHERE id=$1", kunde_id
        )
        if not exists:
            raise HTTPException(404, f"Kunde {kunde_id} nicht gefunden")
        try:
            wert = await c.fetchval(
                "SELECT pkg_faktura.kunde_umsatz($1)", kunde_id
            )
        except asyncpg.exceptions.RaiseError as e:
            # Named Exception aus Oracle -> SQLSTATE 50001 (Kunde unbekannt)
            if getattr(e, "sqlstate", None) == "50001":
                raise HTTPException(404, f"Kunde {kunde_id} nicht gefunden")
            raise
    return {"kunde_id": kunde_id, "umsatz": wert}


@app.get(
    "/rechnungen/{rechnung_id}",
    response_model=RechnungDetail,
    tags=["rechnungen"],
)
async def rechnung_detail(rechnung_id: int):
    async with app.state.pool.acquire() as c:
        kopf = await c.fetchrow(
            "SELECT * FROM app_demo.rechnungen WHERE id=$1", rechnung_id
        )
        if not kopf:
            raise HTTPException(404, f"Rechnung {rechnung_id} nicht gefunden")
        pos = await c.fetch(
            """SELECT id, position, beschreibung, menge, einheit,
                      einzelpreis, gesamtpreis
                 FROM app_demo.rechnungspositionen
                WHERE rechnung_id=$1
                ORDER BY position""",
            rechnung_id,
        )
    return {**dict(kopf), "positionen": [dict(p) for p in pos]}


@app.get(
    "/rechnungen/{rechnung_id}/summe",
    response_model=RechnungSumme,
    tags=["rechnungen"],
)
async def rechnung_summe(rechnung_id: int):
    """Ruft die migrierte PL/pgSQL-Funktion pkg_faktura.berechne_rechnungssumme auf.

    Demonstriert, dass die aus Oracle-PL/SQL portierte Package-Logik
    unveraendert aus der App heraus nutzbar ist.
    """
    async with app.state.pool.acquire() as c:
        # Existenz-Check: liefert 404, bevor die Funktion aufgerufen wird
        exists = await c.fetchval(
            "SELECT 1 FROM app_demo.rechnungen WHERE id=$1", rechnung_id
        )
        if not exists:
            raise HTTPException(404, f"Rechnung {rechnung_id} nicht gefunden")
        try:
            wert = await c.fetchval(
                "SELECT pkg_faktura.berechne_rechnungssumme($1)", rechnung_id
            )
        except asyncpg.exceptions.RaiseError as e:
            # Named Exception aus Oracle -> SQLSTATE 50002 (Rechnung unbekannt)
            if getattr(e, "sqlstate", None) == "50002":
                raise HTTPException(404, f"Rechnung {rechnung_id} nicht gefunden")
            raise
    return {"rechnung_id": rechnung_id, "summe": wert}


@app.get("/umsatz", response_model=List[Umsatz], tags=["auswertung"])
async def umsatz():
    async with app.state.pool.acquire() as c:
        rows = await c.fetch(
            "SELECT * FROM app_demo.v_kunde_umsatz ORDER BY umsatz_bezahlt DESC"
        )
    return [dict(r) for r in rows]


@app.post(
    "/kunden", response_model=Kunde, status_code=201, tags=["kunden"]
)
async def create_kunde(k: KundeIn):
    async with app.state.pool.acquire() as c:
        try:
            row = await c.fetchrow(
                """INSERT INTO app_demo.kunden
                     (anrede, vorname, name, email, telefon,
                      strasse, plz, ort, land)
                   VALUES ($1,$2,$3,$4,$5,$6,$7,$8,$9)
                   RETURNING *""",
                k.anrede, k.vorname, k.name, k.email, k.telefon,
                k.strasse, k.plz, k.ort, k.land,
            )
        except asyncpg.UniqueViolationError:
            raise HTTPException(409, "E-Mail existiert bereits")
    return dict(row)
