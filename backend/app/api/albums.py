from typing import List
from fastapi import APIRouter, Depends, HTTPException
from fastapi.responses import FileResponse, Response
from sqlalchemy.orm import Session
from sqlalchemy import asc

from app.config import settings
from app.database import get_db
from app.models import Album, Song, Favorite
from app.schemas import AlbumResponse, SongResponse

router = APIRouter(prefix="/api/albums", tags=["Albums"])

DEFAULT_PLACEHOLDER_SVG = """<svg xmlns="http://www.w3.org/2000/svg" width="300" height="300" viewBox="0 0 300 300">
  <rect width="100%" height="100%" fill="#1e1e2e"/>
  <circle cx="150" cy="150" r="80" fill="#313244"/>
  <path d="M140 110 v80 l60 -40 z" fill="#cba6f7"/>
  <text x="50%" y="85%" font-family="sans-serif" font-size="16" fill="#a6adc8" text-anchor="middle">LAN Music Player</text>
</svg>"""

@router.get("", response_model=List[AlbumResponse])
def list_albums(db: Session = Depends(get_db)):
    return db.query(Album).order_by(asc(Album.title)).all()

@router.get("/{album_id}", response_model=AlbumResponse)
def get_album(album_id: int, db: Session = Depends(get_db)):
    album = db.query(Album).filter(Album.id == album_id).first()
    if not album:
        raise HTTPException(status_code=404, detail="Album not found")
    return album

@router.get("/{album_id}/songs", response_model=List[SongResponse])
def get_album_songs(album_id: int, db: Session = Depends(get_db)):
    from app.scanner import normalize_movie_album
    album = db.query(Album).filter(Album.id == album_id).first()
    if not album:
        raise HTTPException(status_code=404, detail="Album not found")

    all_songs = db.query(Song).all()
    songs = [
        s for s in all_songs
        if s.album == album.title or normalize_movie_album(s.album) == album.title or album.title.lower() in s.album.lower()
    ]
    songs.sort(key=lambda s: (s.disc_number or 1, s.track_number or 999, s.title))

    fav_ids = set(f.song_id for f in db.query(Favorite.song_id).all())

    results = []
    for s in songs:
        res = SongResponse.model_validate(s)
        res.is_favorite = (s.id in fav_ids)
        results.append(res)

    return results

@router.get("/{album_id}/cover")
def get_album_cover(album_id: int, db: Session = Depends(get_db)):
    album = db.query(Album).filter(Album.id == album_id).first()
    if not album:
        raise HTTPException(status_code=404, detail="Album not found")

    if album.cover_art_path:
        cover_file = settings.CACHE_DIR / album.cover_art_path
        if cover_file.exists():
            return FileResponse(cover_file, media_type="image/jpeg")

    song_with_cover = db.query(Song).filter(Song.album == album.title, Song.cover_art_path.isnot(None)).first()
    if song_with_cover and song_with_cover.cover_art_path:
        cover_file = settings.CACHE_DIR / song_with_cover.cover_art_path
        if cover_file.exists():
            return FileResponse(cover_file, media_type="image/jpeg")

    return Response(content=DEFAULT_PLACEHOLDER_SVG, media_type="image/svg+xml")
