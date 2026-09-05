import os
from pathlib import Path
from typing import Optional
from fastapi import APIRouter, Depends, HTTPException, Query

from sqlalchemy.orm import Session

from app.config import settings
from app.database import get_db
from app.models import Song, Artist, Album
from app.scanner import scanner_instance, SUPPORTED_EXTENSIONS
from app.schemas import (
    SystemStatusResponse,
    ScanStatusResponse,
    DirectoryUpdateRequest,
    DirectoryBrowseResponse,
    DirectoryItem
)

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

@router.get("/system/browse", response_model=DirectoryBrowseResponse)
def browse_directories(path: Optional[str] = Query(None, description="Absolute path to browse")):
    target_path = Path(path) if path else Path(settings.MUSIC_LIBRARY_PATH)
    
    if not target_path.exists() or not target_path.is_dir():
        target_path = Path("/")

    items = []
    try:
        entries = sorted(os.scandir(target_path), key=lambda e: (not e.is_dir(), e.name.lower()))
        for entry in entries:
            if entry.name.startswith('.'):
                continue
            if entry.is_dir(follow_symlinks=False):
                entry_path = Path(entry.path)
                has_music = False
                try:
                    for child in os.scandir(entry_path):
                        if child.is_file(follow_symlinks=False):
                            if Path(child.name).suffix.lower() in SUPPORTED_EXTENSIONS:
                                has_music = True
                                break
                except Exception:
                    pass
                items.append(DirectoryItem(
                    name=entry.name,
                    path=str(entry_path),
                    is_dir=True,
                    has_music=has_music
                ))
    except PermissionError:
        raise HTTPException(status_code=403, detail=f"Permission denied accessing directory: {target_path}")
    except Exception as e:
        raise HTTPException(status_code=500, detail=str(e))

    parent_path = str(target_path.parent) if target_path.parent != target_path else None

    return DirectoryBrowseResponse(
        current_path=str(target_path),
        parent_path=parent_path,
        items=items
    )

@router.post("/system/directory")
def update_music_directory(req: DirectoryUpdateRequest):
    target_path = Path(req.path)
    if not target_path.exists():
        raise HTTPException(status_code=400, detail="Specified path does not exist")
    if not target_path.is_dir():
        raise HTTPException(status_code=400, detail="Specified path is not a directory")
    if not os.access(target_path, os.R_OK):
        raise HTTPException(status_code=403, detail="Directory is not readable by server")

    success = settings.update_music_library_path(str(target_path.resolve()))
    if not success:
        raise HTTPException(status_code=500, detail="Failed to persist configuration")

    scan_started = False
    if req.rescan:
        scan_started = scanner_instance.start_scan()

    return {
        "message": "Music directory path updated successfully",
        "music_path": settings.MUSIC_LIBRARY_PATH,
        "scan_initiated": scan_started
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

