from fastapi import APIRouter, Depends, Query
from sqlalchemy.orm import Session
from sqlalchemy import or_

from app.database import get_db
from app.models import Song, Artist, Album, Favorite
from app.schemas import SearchResponse, SongResponse, ArtistResponse, AlbumResponse

router = APIRouter(prefix="/api/search", tags=["Search"])

@router.get("", response_model=SearchResponse)
def search_library(q: str = Query(..., min_length=1), limit: int = Query(20, ge=1, le=100), db: Session = Depends(get_db)):
    search_term = f"%{q.strip()}%"

    matching_songs = db.query(Song).filter(
        or_(
            Song.title.ilike(search_term),
            Song.artist.ilike(search_term),
            Song.album.ilike(search_term),
            Song.genre.ilike(search_term)
        )
    ).limit(limit).all()

    matching_artists = db.query(Artist).filter(
        Artist.name.ilike(search_term)
    ).limit(limit).all()

    matching_albums = db.query(Album).filter(
        or_(
            Album.title.ilike(search_term),
            Album.artist.ilike(search_term)
        )
    ).limit(limit).all()

    fav_ids = set(f.song_id for f in db.query(Favorite.song_id).all())

    song_results = []
    for s in matching_songs:
        res = SongResponse.model_validate(s)
        res.is_favorite = (s.id in fav_ids)
        song_results.append(res)

    return {
        "songs": song_results,
        "artists": [ArtistResponse.model_validate(a) for a in matching_artists],
        "albums": [AlbumResponse.model_validate(alb) for alb in matching_albums]
    }
