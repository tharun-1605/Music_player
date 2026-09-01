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

