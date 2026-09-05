from typing import List
from fastapi import APIRouter, Depends, HTTPException
from sqlalchemy.orm import Session
from sqlalchemy import asc, or_

from app.database import get_db
from app.models import Artist, Song, Album, Favorite
from app.schemas import ArtistResponse, SongResponse, AlbumResponse

router = APIRouter(prefix="/api/artists", tags=["Artists"])

@router.get("", response_model=List[ArtistResponse])
def list_artists(db: Session = Depends(get_db)):
    return db.query(Artist).order_by(asc(Artist.name)).all()

@router.get("/{artist_id}", response_model=ArtistResponse)
def get_artist(artist_id: int, db: Session = Depends(get_db)):
    artist = db.query(Artist).filter(Artist.id == artist_id).first()
    if not artist:
        raise HTTPException(status_code=404, detail="Artist not found")
    return artist

@router.get("/{artist_id}/songs", response_model=List[SongResponse])
def get_artist_songs(artist_id: int, db: Session = Depends(get_db)):
    artist = db.query(Artist).filter(Artist.id == artist_id).first()
    if not artist:
        raise HTTPException(status_code=404, detail="Artist not found")

    search_pattern = f"%{artist.name}%"
    songs = db.query(Song).filter(
        or_(
            Song.artist == artist.name,
            Song.artist.ilike(search_pattern),
            Song.album_artist == artist.name
        )
    ).order_by(asc(Song.title)).all()

    fav_ids = set(f.song_id for f in db.query(Favorite.song_id).all())

    results = []
    for s in songs:
        res = SongResponse.model_validate(s)
        res.is_favorite = (s.id in fav_ids)
        results.append(res)

    return results

@router.get("/{artist_id}/albums", response_model=List[AlbumResponse])
def get_artist_albums(artist_id: int, db: Session = Depends(get_db)):
    artist = db.query(Artist).filter(Artist.id == artist_id).first()
    if not artist:
        raise HTTPException(status_code=404, detail="Artist not found")

    search_pattern = f"%{artist.name}%"
    # Find all album titles containing songs by this artist
    album_titles_query = db.query(Song.album).filter(
        or_(
            Song.artist == artist.name,
            Song.artist.ilike(search_pattern),
            Song.album_artist == artist.name
        )
    ).distinct().all()
    matching_titles = [t[0] for t in album_titles_query if t[0]]

    return db.query(Album).filter(
        or_(
            Album.artist == artist.name,
            Album.title.in_(matching_titles)
        )
    ).order_by(asc(Album.title)).all()

@router.get("/{artist_id}/image")
@router.get("/{artist_id}/cover")
def get_artist_image(artist_id: int, db: Session = Depends(get_db)):
    artist = db.query(Artist).filter(Artist.id == artist_id).first()
    if not artist:
        raise HTTPException(status_code=404, detail="Artist not found")

    from app.artist_images import get_artist_image_file
    from fastapi.responses import FileResponse, Response

    image_path = get_artist_image_file(artist.name)
    if image_path and image_path.exists():
        return FileResponse(path=image_path, media_type="image/jpeg")

    initial = artist.name[0].upper() if artist.name else "A"
    svg = f'''<svg xmlns="http://www.w3.org/2000/svg" width="300" height="300" viewBox="0 0 300 300">
      <defs>
        <linearGradient id="g" x1="0%" y1="0%" x2="100%" y2="100%">
          <stop offset="0%" stop-color="#4F46E5"/>
          <stop offset="100%" stop-color="#9333EA"/>
        </linearGradient>
      </defs>
      <rect width="100%" height="100%" fill="url(#g)"/>
      <circle cx="150" cy="120" r="48" fill="#ffffff" opacity="0.25"/>
      <path d="M90 230 C90 185, 210 185, 210 230 Z" fill="#ffffff" opacity="0.25"/>
      <text x="50%" y="54%" font-family="sans-serif" font-weight="bold" font-size="64" fill="#ffffff" text-anchor="middle" dominant-baseline="central">{initial}</text>
    </svg>'''
    return Response(content=svg, media_type="image/svg+xml")

