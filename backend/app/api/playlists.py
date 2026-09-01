from typing import List
from fastapi import APIRouter, Depends, HTTPException, status
from sqlalchemy.orm import Session
from sqlalchemy import asc

from app.database import get_db
from app.models import Playlist, PlaylistSong, Song, Favorite
from app.schemas import PlaylistCreate, PlaylistResponse, PlaylistDetailResponse, SongResponse

router = APIRouter(prefix="/api/playlists", tags=["Playlists"])

@router.post("", response_model=PlaylistResponse, status_code=status.HTTP_201_CREATED)
def create_playlist(payload: PlaylistCreate, db: Session = Depends(get_db)):
    existing = db.query(Playlist).filter(Playlist.name == payload.name.strip()).first()
    if existing:
        raise HTTPException(status_code=400, detail="Playlist with this name already exists")

    pl = Playlist(name=payload.name.strip())
    db.add(pl)
    db.commit()
    db.refresh(pl)
    return PlaylistResponse(id=pl.id, name=pl.name, song_count=0, created_at=pl.created_at)

@router.get("", response_model=List[PlaylistResponse])
def list_playlists(db: Session = Depends(get_db)):
    playlists = db.query(Playlist).order_by(asc(Playlist.name)).all()
    results = []
    for pl in playlists:
        count = db.query(PlaylistSong).filter(PlaylistSong.playlist_id == pl.id).count()
        results.append(PlaylistResponse(id=pl.id, name=pl.name, song_count=count, created_at=pl.created_at))
    return results

@router.get("/{playlist_id}", response_model=PlaylistDetailResponse)
def get_playlist(playlist_id: int, db: Session = Depends(get_db)):
    pl = db.query(Playlist).filter(Playlist.id == playlist_id).first()
    if not pl:
        raise HTTPException(status_code=404, detail="Playlist not found")

    ps_records = db.query(PlaylistSong).filter(PlaylistSong.playlist_id == playlist_id).order_by(asc(PlaylistSong.position)).all()
    song_ids = [ps.song_id for ps in ps_records]

    songs = []
    if song_ids:
        fav_ids = set(f.song_id for f in db.query(Favorite.song_id).all())
        song_map = {s.id: s for s in db.query(Song).filter(Song.id.in_(song_ids)).all()}
        for ps in ps_records:
            s = song_map.get(ps.song_id)
            if s:
                res = SongResponse.model_validate(s)
                res.is_favorite = (s.id in fav_ids)
                songs.append(res)

    return PlaylistDetailResponse(
        id=pl.id,
        name=pl.name,
        song_count=len(songs),
        created_at=pl.created_at,
        songs=songs
    )

@router.post("/{playlist_id}/songs/{song_id}")
def add_song_to_playlist(playlist_id: int, song_id: int, db: Session = Depends(get_db)):
    pl = db.query(Playlist).filter(Playlist.id == playlist_id).first()
    if not pl:
        raise HTTPException(status_code=404, detail="Playlist not found")

    song = db.query(Song).filter(Song.id == song_id).first()
    if not song:
        raise HTTPException(status_code=404, detail="Song not found")

    max_pos = db.query(PlaylistSong).filter(PlaylistSong.playlist_id == playlist_id).count()
    ps = PlaylistSong(playlist_id=playlist_id, song_id=song_id, position=max_pos + 1)
    db.add(ps)
    db.commit()

    return {"message": f"Added '{song.title}' to playlist '{pl.name}'"}

@router.delete("/{playlist_id}/songs/{song_id}")
def remove_song_from_playlist(playlist_id: int, song_id: int, db: Session = Depends(get_db)):
    ps = db.query(PlaylistSong).filter(PlaylistSong.playlist_id == playlist_id, PlaylistSong.song_id == song_id).first()
    if not ps:
        raise HTTPException(status_code=404, detail="Song not found in playlist")

    db.delete(ps)
    db.commit()
    return {"message": "Song removed from playlist"}

@router.delete("/{playlist_id}")
def delete_playlist(playlist_id: int, db: Session = Depends(get_db)):
    pl = db.query(Playlist).filter(Playlist.id == playlist_id).first()
    if not pl:
        raise HTTPException(status_code=404, detail="Playlist not found")

    db.delete(pl)
    db.commit()
    return {"message": "Playlist deleted successfully"}
