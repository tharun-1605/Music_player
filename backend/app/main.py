from fastapi import FastAPI
from fastapi.middleware.cors import CORSMiddleware
from contextlib import asynccontextmanager

from app.config import settings
from app.database import engine, Base, SessionLocal
from app.models import Song
from app.scanner import scanner_instance

from app.api import system, songs, artists, albums, search, playlists, favorites, history

@asynccontextmanager
async def lifespan(app: FastAPI):
    # Create DB tables
    Base.metadata.create_all(bind=engine)

    # Initial scan if database is empty
    db = SessionLocal()
    try:
        count = db.query(Song).count()
        if count == 0:
            scanner_instance.start_scan()
    finally:
        db.close()

    yield

app = FastAPI(
    title="LAN Music Streaming Backend",
    description="High-performance LAN-only music server with HTTP 206 streaming and Mutagen metadata indexing.",
    version="1.0.0",
    lifespan=lifespan
)

# Enable CORS for local network clients
app.add_middleware(
    CORSMiddleware,
    allow_origins=["*"],
    allow_credentials=True,
    allow_methods=["*"],
    allow_headers=["*"],
)

# Include Routers
app.include_router(system.router)
app.include_router(songs.router)
app.include_router(artists.router)
app.include_router(albums.router)
app.include_router(search.router)
app.include_router(playlists.router)
app.include_router(favorites.router)
app.include_router(history.router)
