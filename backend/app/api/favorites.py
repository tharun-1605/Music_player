from typing import List
from fastapi import APIRouter, Depends, HTTPException, status
from sqlalchemy.orm import Session
from sqlalchemy import desc

from app.database import get_db
from app.models import Favorite, Song
from app.schemas import SongResponse

router = APIRouter(prefix="/api/favorites", tags=["Favorites"])

@router.post("/{song_id}", status_code=status.HTTP_201_CREATED)
def add_favorite(song_id: int, db: Session = Depends(get_db)):
    song = db.query(Song).filter(Song.id == song_id).first()
    if not song:
        raise HTTPException(status_code=404, detail="Song not found")

    existing = db.query(Favorite).filter(Favorite.song_id == song_id).first()
    if existing:
        return {"message": "Song already in favorites", "is_favorite": True}

    fav = Favorite(song_id=song_id)
    db.add(fav)
    db.commit()
    return {"message": "Added to favorites", "is_favorite": True}

@router.delete("/{song_id}")
def remove_favorite(song_id: int, db: Session = Depends(get_db)):
    fav = db.query(Favorite).filter(Favorite.song_id == song_id).first()
    if not fav:
        return {"message": "Song was not in favorites", "is_favorite": False}

    db.delete(fav)
    db.commit()
    return {"message": "Removed from favorites", "is_favorite": False}

@router.get("", response_model=List[SongResponse])
def get_favorites(db: Session = Depends(get_db)):
    favs = db.query(Favorite).order_by(desc(Favorite.created_at)).all()
    song_ids = [f.song_id for f in favs]

    if not song_ids:
        return []

    song_map = {s.id: s for s in db.query(Song).filter(Song.id.in_(song_ids)).all()}
    results = []
    for f in favs:
        s = song_map.get(f.song_id)
        if s:
            res = SongResponse.model_validate(s)
            res.is_favorite = True
            results.append(res)
    return results
