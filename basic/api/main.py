"""
Basic Demo API – migriertes Schema app_basic_demo in PostgreSQL.

Dieses Backend zeigt, dass nach einer sauberen Oracle-Migration
(keine manuellen Patches) die Daten sofort via REST abrufbar sind.

Endpoints (Auto-Docs unter /docs):
  GET  /health
  GET  /produkte
  GET  /produkte/{id}
  GET  /bestellungen
  GET  /bestellungen/{id}
  POST /bestellungen
"""

from contextlib import asynccontextmanager
from datetime import datetime
from decimal import Decimal
from typing import List, Optional
import os

import asyncpg
from fastapi import FastAPI, HTTPException
from pydantic import BaseModel

DB_DSN = os.getenv("DB_DSN", "postgresql://demo:demo@postgres:5432/demo")


@asynccontextmanager
async def lifespan(app: FastAPI):
    app.state.pool = await asyncpg.create_pool(
        DB_DSN,
        min_size=1,
        max_size=5,
        server_settings={"search_path": "app_basic_demo, public"},
    )
    yield
    await app.state.pool.close()


app = FastAPI(
    title="Basic Demo API",
    description=(
        "Demo-Backend fuer das migrierte Schema app_basic_demo. "
        "Zeigt eine saubere Oracle→PostgreSQL-Migration ohne manuelle Nacharbeit."
    ),
    version="1.0.0",
    lifespan=lifespan,
)


# ---------- Pydantic-Modelle ----------

class Produkt(BaseModel):
    id: int
    name: str
    beschreibung: Optional[str]
    preis: Decimal
    lagerbestand: int
    erstellt_am: datetime


class BestellungIn(BaseModel):
    produkt_id: int
    menge: int


class Bestellung(BaseModel):
    id: int
    produkt_id: int
    menge: int
    bestelldatum: datetime
    aktualisiert_am: Optional[datetime]


class BestellungDetail(Bestellung):
    produkt_name: str
    produkt_preis: Decimal
    gesamtpreis: Decimal


# ---------- Endpoints ----------

@app.get("/health", tags=["meta"])
async def health():
    async with app.state.pool.acquire() as c:
        await c.execute("SELECT 1")
    return {"status": "ok"}


@app.get("/produkte", response_model=List[Produkt], tags=["produkte"])
async def list_produkte():
    async with app.state.pool.acquire() as c:
        rows = await c.fetch(
            "SELECT * FROM app_basic_demo.produkte ORDER BY name"
        )
    return [dict(r) for r in rows]


@app.get("/produkte/{produkt_id}", response_model=Produkt, tags=["produkte"])
async def get_produkt(produkt_id: int):
    async with app.state.pool.acquire() as c:
        row = await c.fetchrow(
            "SELECT * FROM app_basic_demo.produkte WHERE id=$1", produkt_id
        )
    if not row:
        raise HTTPException(404, f"Produkt {produkt_id} nicht gefunden")
    return dict(row)


@app.get("/bestellungen", response_model=List[BestellungDetail], tags=["bestellungen"])
async def list_bestellungen():
    async with app.state.pool.acquire() as c:
        rows = await c.fetch(
            """SELECT b.id, b.produkt_id, b.menge, b.bestelldatum, b.aktualisiert_am,
                      p.name AS produkt_name, p.preis AS produkt_preis,
                      (b.menge * p.preis) AS gesamtpreis
                 FROM app_basic_demo.bestellungen b
                 JOIN app_basic_demo.produkte p ON p.id = b.produkt_id
                ORDER BY b.bestelldatum DESC, b.id DESC"""
        )
    return [dict(r) for r in rows]


@app.get(
    "/bestellungen/{bestellung_id}",
    response_model=BestellungDetail,
    tags=["bestellungen"],
)
async def get_bestellung(bestellung_id: int):
    async with app.state.pool.acquire() as c:
        row = await c.fetchrow(
            """SELECT b.id, b.produkt_id, b.menge, b.bestelldatum, b.aktualisiert_am,
                      p.name AS produkt_name, p.preis AS produkt_preis,
                      (b.menge * p.preis) AS gesamtpreis
                 FROM app_basic_demo.bestellungen b
                 JOIN app_basic_demo.produkte p ON p.id = b.produkt_id
                WHERE b.id=$1""",
            bestellung_id,
        )
    if not row:
        raise HTTPException(404, f"Bestellung {bestellung_id} nicht gefunden")
    return dict(row)


@app.post(
    "/bestellungen", response_model=Bestellung, status_code=201, tags=["bestellungen"]
)
async def create_bestellung(b: BestellungIn):
    async with app.state.pool.acquire() as c:
        produkt = await c.fetchrow(
            "SELECT id FROM app_basic_demo.produkte WHERE id=$1", b.produkt_id
        )
        if not produkt:
            raise HTTPException(404, f"Produkt {b.produkt_id} nicht gefunden")
        row = await c.fetchrow(
            """INSERT INTO app_basic_demo.bestellungen (produkt_id, menge)
               VALUES ($1, $2)
               RETURNING *""",
            b.produkt_id, b.menge,
        )
    return dict(row)
