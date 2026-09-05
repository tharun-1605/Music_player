from datetime import datetime
from typing import List
from pydantic import BaseModel
from fastapi import APIRouter, Depends, HTTPException, status
from sqlalchemy.orm import Session
from sqlalchemy import desc, func

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

@router.get("/stats")
def get_replay_stats(db: Session = Depends(get_db)):
    total_plays = db.query(PlayHistory).count()
    
    duration_res = db.query(func.sum(Song.duration)).join(PlayHistory, Song.id == PlayHistory.song_id).scalar()
    total_seconds = duration_res or 0.0
    total_minutes = round(total_seconds / 60.0, 1)

    now = datetime.utcnow()
    month_start = datetime(now.year, now.month, 1)
    month_duration = db.query(func.sum(Song.duration)).join(PlayHistory, Song.id == PlayHistory.song_id).filter(PlayHistory.played_at >= month_start).scalar()
    month_minutes = round((month_duration or 0.0) / 60.0, 1)

    top_song_counts = db.query(Song, func.count(PlayHistory.id).label("play_count"))\
        .join(PlayHistory, Song.id == PlayHistory.song_id)\
        .group_by(Song.id)\
        .order_by(desc("play_count"))\
        .limit(5).all()

    fav_ids = set(f.song_id for f in db.query(Favorite.song_id).all())
    top_songs = []
    for song, count in top_song_counts:
        s_res = SongResponse.model_validate(song)
        s_res.is_favorite = (song.id in fav_ids)
        top_songs.append({"song": s_res, "play_count": count})

    top_album_counts = db.query(Song.album, func.count(PlayHistory.id).label("play_count"))\
        .join(PlayHistory, Song.id == PlayHistory.song_id)\
        .filter(Song.album != "Unknown Album")\
        .group_by(Song.album)\
        .order_by(desc("play_count"))\
        .limit(5).all()
    top_albums = [{"album": alb, "play_count": cnt} for alb, cnt in top_album_counts]

    top_artist_counts = db.query(Song.artist, func.count(PlayHistory.id).label("play_count"))\
        .join(PlayHistory, Song.id == PlayHistory.song_id)\
        .filter(Song.artist != "Unknown Artist")\
        .group_by(Song.artist)\
        .order_by(desc("play_count"))\
        .limit(5).all()
    top_artists = [{"artist": art, "play_count": cnt} for art, cnt in top_artist_counts]

    return {
        "total_plays": total_plays,
        "total_minutes": total_minutes,
        "month_minutes": month_minutes,
        "top_songs": top_songs,
        "top_albums": top_albums,
        "top_artists": top_artists
    }

