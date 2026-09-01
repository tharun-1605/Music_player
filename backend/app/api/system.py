import os
from pathlib import Path
from fastapi import APIRouter, Depends
from sqlalchemy.orm import Session

from app.config import settings
from app.database import get_db
from app.models import Song, Artist, Album
from app.scanner import scanner_instance
from app.schemas import SystemStatusResponse, ScanStatusResponse

router = APIRouter(prefix="/api", tags=["System"])

@router.get("/health")
def health_check():
    return {
        "status": "ok",
        "library": settings.MUSIC_LIBRARY_PATH
    }

@router.get("/system/status", response_model=SystemStatusResponse)
def get_system_status(db: Session = Depends(get_db)):
    music_path = Path(settings.MUSIC_LIBRARY_PATH)
    hdd_connected = music_path.exists()
    readable = os.access(music_path, os.R_OK) if hdd_connected else False

    total_files = 0
    if readable:
        for root, _, files in os.walk(music_path):
            total_files += len(files)

    total_songs = db.query(Song).count()
    total_artists = db.query(Artist).count()
    total_albums = db.query(Album).count()

    return {
        "hdd_connected": hdd_connected,
        "music_path": str(music_path),
        "readable": readable,
        "total_files": total_files,
        "db_status": "ok",
        "total_songs_in_db": total_songs,
        "total_artists_in_db": total_artists,
        "total_albums_in_db": total_albums
    }

@router.post("/library/scan")
def trigger_library_scan():
    started = scanner_instance.start_scan()
    if not started:
        return {"message": "Scan already in progress", "started": False}
    return {"message": "Library scan initiated", "started": True}

@router.get("/library/status", response_model=ScanStatusResponse)
def get_scan_status(db: Session = Depends(get_db)):
    return scanner_instance.get_status(db)
