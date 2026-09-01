from typing import List
from pydantic import BaseModel
from fastapi import APIRouter, Depends, HTTPException, status
from sqlalchemy.orm import Session
from sqlalchemy import desc

from app.database import get_db
from app.models import PlayHistory, Song, Favorite
from app.schemas import SongResponse

router = APIRouter(prefix="/api/history", tags=["History"])

class HistoryAddPayload(BaseModel):
    song_id: int

@router.post("", status_code=status.HTTP_201_CREATED)
def record_history(payload: HistoryAddPayload, db: Session = Depends(get_db)):
    song = db.query(Song).filter(Song.id == payload.song_id).first()
    if not song:
        raise HTTPException(status_code=404, detail="Song not found")

    entry = PlayHistory(song_id=payload.song_id)
    db.add(entry)
    db.commit()
    return {"message": "Play history recorded"}

@router.get("", response_model=List[SongResponse])
def get_history(limit: int = 30, db: Session = Depends(get_db)):
    history_entries = db.query(PlayHistory).order_by(desc(PlayHistory.played_at)).limit(limit).all()
    if not history_entries:
        return []

    fav_ids = set(f.song_id for f in db.query(Favorite.song_id).all())
    song_ids = [h.song_id for h in history_entries]
    song_map = {s.id: s for s in db.query(Song).filter(Song.id.in_(song_ids)).all()}

    results = []
    seen = set()
    for h in history_entries:
        if h.song_id in seen:
            continue
        seen.add(h.song_id)
        s = song_map.get(h.song_id)
        if s:
            res = SongResponse.model_validate(s)
            res.is_favorite = (s.id in fav_ids)
            results.append(res)
    return results
