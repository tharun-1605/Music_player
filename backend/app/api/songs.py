from typing import Optional
from pathlib import Path
from fastapi import APIRouter, Depends, HTTPException, Query, Request, status
from fastapi.responses import FileResponse, Response
from sqlalchemy.orm import Session
from sqlalchemy import asc, desc

from app.config import settings
from app.database import get_db
from app.models import Song, Favorite
from app.schemas import SongResponse, SongListResponse
from app.streaming import stream_audio_file

router = APIRouter(prefix="/api/songs", tags=["Songs"])

DEFAULT_PLACEHOLDER_SVG = """<svg xmlns="http://www.w3.org/2000/svg" width="300" height="300" viewBox="0 0 300 300">
  <rect width="100%" height="100%" fill="#1e1e2e"/>
  <circle cx="150" cy="150" r="80" fill="#313244"/>
  <path d="M140 110 v80 l60 -40 z" fill="#cba6f7"/>
  <text x="50%" y="85%" font-family="sans-serif" font-size="16" fill="#a6adc8" text-anchor="middle">LAN Music Player</text>
</svg>"""

@router.get("", response_model=SongListResponse)
def list_songs(
    page: int = Query(1, ge=1),
    limit: int = Query(50, ge=1, le=500),
    artist: Optional[str] = None,
    album: Optional[str] = None,
    genre: Optional[str] = None,
    sort: str = Query("title", pattern="^(title|artist|album|duration|year|track_number|created_at)$"),
    order: str = Query("asc", pattern="^(asc|desc)$"),
    db: Session = Depends(get_db)
):
    query = db.query(Song)

    if artist:
        query = query.filter(Song.artist.ilike(f"%{artist}%"))
    if album:
        query = query.filter(Song.album.ilike(f"%{album}%"))
    if genre:
        query = query.filter(Song.genre.ilike(f"%{genre}%"))

    total = query.count()

    sort_column = getattr(Song, sort, Song.title)
    if order.lower() == "desc":
        query = query.order_by(desc(sort_column))
    else:
        query = query.order_by(asc(sort_column))

    offset = (page - 1) * limit
    songs = query.offset(offset).limit(limit).all()

    # Favorites check
    fav_ids = set(f.song_id for f in db.query(Favorite.song_id).all())

    result_songs = []
    for s in songs:
        s_dict = SongResponse.model_validate(s)
        s_dict.is_favorite = (s.id in fav_ids)
        result_songs.append(s_dict)

    return {
        "total": total,
        "page": page,
        "limit": limit,
        "songs": result_songs
    }

@router.get("/{song_id}", response_model=SongResponse)
def get_song(song_id: int, db: Session = Depends(get_db)):
    song = db.query(Song).filter(Song.id == song_id).first()
    if not song:
        raise HTTPException(status_code=404, detail="Song not found")

    is_fav = db.query(Favorite).filter(Favorite.song_id == song_id).first() is not None
    resp = SongResponse.model_validate(song)
    resp.is_favorite = is_fav
    return resp

@router.get("/{song_id}/stream")
def stream_song(song_id: int, request: Request, db: Session = Depends(get_db)):
    song = db.query(Song).filter(Song.id == song_id).first()
    if not song:
        raise HTTPException(status_code=404, detail="Song not found")
    
    return stream_audio_file(request, song.file_path, settings.MUSIC_LIBRARY_PATH)

@router.get("/{song_id}/cover")
def get_song_cover(song_id: int, db: Session = Depends(get_db)):
    song = db.query(Song).filter(Song.id == song_id).first()
    if not song:
        raise HTTPException(status_code=404, detail="Song not found")

    if song.cover_art_path:
        cover_file = settings.CACHE_DIR / song.cover_art_path
        if cover_file.exists():
            return FileResponse(cover_file, media_type="image/jpeg")

    return Response(content=DEFAULT_PLACEHOLDER_SVG, media_type="image/svg+xml")
