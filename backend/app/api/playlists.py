import io
from typing import List
from fastapi import APIRouter, Depends, HTTPException, Response, status
from sqlalchemy.orm import Session
from sqlalchemy import asc
from PIL import Image

from app.config import settings
from app.database import get_db
from app.models import Playlist, PlaylistSong, Song, Favorite, Album
from app.schemas import (
    PlaylistCreate,
    PlaylistUpdate,
    PlaylistResponse,
    PlaylistDetailResponse,
    PlaylistBatchSongs,
    PlaylistReorder,
    SongResponse,
)

router = APIRouter(prefix="/api/playlists", tags=["Playlists"])

DEFAULT_PLAYLIST_SVG = """<svg xmlns="http://www.w3.org/2000/svg" width="300" height="300" viewBox="0 0 300 300">
  <rect width="100%" height="100%" fill="#2a2b3d"/>
  <path d="M110 100 v100 l90 -50 z" fill="#1DB954"/>
  <text x="50%" y="85%" font-family="sans-serif" font-size="16" fill="#a6adc8" text-anchor="middle">Playlist</text>
</svg>"""

def _ensure_favorites_playlist(db: Session) -> Playlist:
    fav_pl = db.query(Playlist).filter(Playlist.is_system == 1).first()
    if not fav_pl:
        fav_pl = db.query(Playlist).filter(Playlist.name == "Favorites").first()
        if fav_pl:
            fav_pl.is_system = 1
            db.commit()
        else:
            fav_pl = Playlist(name="Favorites", is_system=1)
            db.add(fav_pl)
            db.commit()
            db.refresh(fav_pl)
    return fav_pl

@router.get("", response_model=List[PlaylistResponse])
def list_playlists(db: Session = Depends(get_db)):
    _ensure_favorites_playlist(db)

    playlists = db.query(Playlist).order_by(Playlist.is_system.desc(), Playlist.name.asc()).all()
    results = []
    for pl in playlists:
        if pl.is_system == 1:
            count = db.query(Favorite).count()
        else:
            count = db.query(PlaylistSong).filter(PlaylistSong.playlist_id == pl.id).count()

        results.append(PlaylistResponse(
            id=pl.id,
            name=pl.name,
            song_count=count,
            is_system=bool(pl.is_system),
            created_at=pl.created_at
        ))
    return results

@router.post("", response_model=PlaylistResponse, status_code=status.HTTP_201_CREATED)
def create_playlist(payload: PlaylistCreate, db: Session = Depends(get_db)):
    name_clean = payload.name.strip()
    if not name_clean:
        raise HTTPException(status_code=400, detail="Playlist name cannot be empty")

    existing = db.query(Playlist).filter(Playlist.name == name_clean).first()
    if existing:
        raise HTTPException(status_code=400, detail="Playlist with this name already exists")

    pl = Playlist(name=name_clean, is_system=0)
    db.add(pl)
    db.commit()
    db.refresh(pl)

    return PlaylistResponse(
        id=pl.id,
        name=pl.name,
        song_count=0,
        is_system=False,
        created_at=pl.created_at
    )

@router.get("/{playlist_id}", response_model=PlaylistDetailResponse)
def get_playlist(playlist_id: int, db: Session = Depends(get_db)):
    pl = db.query(Playlist).filter(Playlist.id == playlist_id).first()
    if not pl:
        raise HTTPException(status_code=404, detail="Playlist not found")

    fav_ids = set(f.song_id for f in db.query(Favorite.song_id).all())
    songs = []

    if pl.is_system == 1:
        # System "Favorites" playlist
        fav_records = db.query(Favorite).order_by(Favorite.created_at.desc()).all()
        song_ids = [f.song_id for f in fav_records]
        if song_ids:
            song_map = {s.id: s for s in db.query(Song).filter(Song.id.in_(song_ids)).all()}
            for f in fav_records:
                s = song_map.get(f.song_id)
                if s:
                    res = SongResponse.model_validate(s)
                    res.is_favorite = True
                    songs.append(res)
    else:
        # Standard user playlist
        ps_records = db.query(PlaylistSong).filter(PlaylistSong.playlist_id == playlist_id).order_by(asc(PlaylistSong.position)).all()
        song_ids = [ps.song_id for ps in ps_records]
        if song_ids:
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
        is_system=bool(pl.is_system),
        created_at=pl.created_at,
        songs=songs
    )

@router.put("/{playlist_id}", response_model=PlaylistResponse)
def rename_playlist(playlist_id: int, payload: PlaylistUpdate, db: Session = Depends(get_db)):
    pl = db.query(Playlist).filter(Playlist.id == playlist_id).first()
    if not pl:
        raise HTTPException(status_code=404, detail="Playlist not found")

    if pl.is_system == 1:
        raise HTTPException(status_code=400, detail="Cannot rename system Favorites playlist")

    name_clean = payload.name.strip()
    if not name_clean:
        raise HTTPException(status_code=400, detail="Playlist name cannot be empty")

    existing = db.query(Playlist).filter(Playlist.name == name_clean, Playlist.id != playlist_id).first()
    if existing:
        raise HTTPException(status_code=400, detail="Another playlist with this name already exists")

    pl.name = name_clean
    db.commit()
    db.refresh(pl)

    count = db.query(PlaylistSong).filter(PlaylistSong.playlist_id == playlist_id).count()
    return PlaylistResponse(
        id=pl.id,
        name=pl.name,
        song_count=count,
        is_system=False,
        created_at=pl.created_at
    )

@router.delete("/{playlist_id}")
def delete_playlist(playlist_id: int, db: Session = Depends(get_db)):
    pl = db.query(Playlist).filter(Playlist.id == playlist_id).first()
    if not pl:
        raise HTTPException(status_code=404, detail="Playlist not found")

    if pl.is_system == 1:
        raise HTTPException(status_code=400, detail="Cannot delete system Favorites playlist")

    db.delete(pl)
    db.commit()
    return {"message": "Playlist deleted successfully"}

@router.post("/{playlist_id}/songs/{song_id}")
def add_song_to_playlist(playlist_id: int, song_id: int, db: Session = Depends(get_db)):
    pl = db.query(Playlist).filter(Playlist.id == playlist_id).first()
    if not pl:
        raise HTTPException(status_code=404, detail="Playlist not found")

    if pl.is_system == 1:
        # Add to favorites
        existing_fav = db.query(Favorite).filter(Favorite.song_id == song_id).first()
        if not existing_fav:
            db.add(Favorite(song_id=song_id))
            db.commit()
        return {"message": "Added to Favorites"}

    song = db.query(Song).filter(Song.id == song_id).first()
    if not song:
        raise HTTPException(status_code=404, detail="Song not found")

    # Duplicate Song Protection
    existing_ps = db.query(PlaylistSong).filter(PlaylistSong.playlist_id == playlist_id, PlaylistSong.song_id == song_id).first()
    if existing_ps:
        return {"message": f"'{song.title}' is already in playlist '{pl.name}'"}

    max_pos = db.query(PlaylistSong).filter(PlaylistSong.playlist_id == playlist_id).count()
    ps = PlaylistSong(playlist_id=playlist_id, song_id=song_id, position=max_pos + 1)
    db.add(ps)
    db.commit()

    return {"message": f"Added '{song.title}' to playlist '{pl.name}'"}

@router.post("/{playlist_id}/songs/batch")
def add_batch_songs_to_playlist(playlist_id: int, payload: PlaylistBatchSongs, db: Session = Depends(get_db)):
    pl = db.query(Playlist).filter(Playlist.id == playlist_id).first()
    if not pl:
        raise HTTPException(status_code=404, detail="Playlist not found")

    if pl.is_system == 1:
        for sid in payload.song_ids:
            if not db.query(Favorite).filter(Favorite.song_id == sid).first():
                db.add(Favorite(song_id=sid))
        db.commit()
        return {"message": "Added batch to Favorites"}

    existing_sids = set(ps.song_id for ps in db.query(PlaylistSong.song_id).filter(PlaylistSong.playlist_id == playlist_id).all())
    current_count = len(existing_sids)

    added_count = 0
    for sid in payload.song_ids:
        if sid not in existing_sids:
            current_count += 1
            db.add(PlaylistSong(playlist_id=playlist_id, song_id=sid, position=current_count))
            existing_sids.add(sid)
            added_count += 1

    db.commit()
    return {"message": f"Added {added_count} songs to playlist '{pl.name}'"}

@router.post("/{playlist_id}/album/{album_id}")
def add_album_to_playlist(playlist_id: int, album_id: int, db: Session = Depends(get_db)):
    album = db.query(Album).filter(Album.id == album_id).first()
    if not album:
        raise HTTPException(status_code=404, detail="Album not found")

    songs = db.query(Song).filter(Song.album == album.title).all()
    song_ids = [s.id for s in songs]

    return add_batch_songs_to_playlist(playlist_id, PlaylistBatchSongs(song_ids=song_ids), db)

@router.delete("/{playlist_id}/songs/{song_id}")
def remove_song_from_playlist(playlist_id: int, song_id: int, db: Session = Depends(get_db)):
    pl = db.query(Playlist).filter(Playlist.id == playlist_id).first()
    if not pl:
        raise HTTPException(status_code=404, detail="Playlist not found")

    if pl.is_system == 1:
        fav = db.query(Favorite).filter(Favorite.song_id == song_id).first()
        if fav:
            db.delete(fav)
            db.commit()
        return {"message": "Removed from Favorites"}

    ps = db.query(PlaylistSong).filter(PlaylistSong.playlist_id == playlist_id, PlaylistSong.song_id == song_id).first()
    if not ps:
        raise HTTPException(status_code=404, detail="Song not found in playlist")

    db.delete(ps)
    db.commit()
    return {"message": "Song removed from playlist"}

@router.put("/{playlist_id}/reorder")
def reorder_playlist_songs(playlist_id: int, payload: PlaylistReorder, db: Session = Depends(get_db)):
    pl = db.query(Playlist).filter(Playlist.id == playlist_id).first()
    if not pl:
        raise HTTPException(status_code=404, detail="Playlist not found")

    if pl.is_system == 1:
        raise HTTPException(status_code=400, detail="Cannot reorder system Favorites playlist")

    # Update position for each song_id in new order
    for idx, sid in enumerate(payload.song_ids):
        ps = db.query(PlaylistSong).filter(PlaylistSong.playlist_id == playlist_id, PlaylistSong.song_id == sid).first()
        if ps:
            ps.position = idx + 1

    db.commit()
    return {"message": "Playlist order updated"}

@router.get("/{playlist_id}/cover")
def get_playlist_cover(playlist_id: int, db: Session = Depends(get_db)):
    pl = db.query(Playlist).filter(Playlist.id == playlist_id).first()
    if not pl:
        raise HTTPException(status_code=404, detail="Playlist not found")

    if pl.is_system == 1:
        fav_records = db.query(Favorite).order_by(Favorite.created_at.desc()).limit(4).all()
        song_ids = [f.song_id for f in fav_records]
    else:
        ps_records = db.query(PlaylistSong).filter(PlaylistSong.playlist_id == playlist_id).order_by(asc(PlaylistSong.position)).limit(4).all()
        song_ids = [ps.song_id for ps in ps_records]

    cover_paths = []
    if song_ids:
        songs = db.query(Song).filter(Song.id.in_(song_ids)).all()
        for s in songs:
            if s.cover_art_path:
                c_file = settings.CACHE_DIR / s.cover_art_path
                if c_file.exists():
                    cover_paths.append(c_file)

    if not cover_paths:
        return Response(content=DEFAULT_PLAYLIST_SVG, media_type="image/svg+xml")

    # Generate 2x2 Collage Image using PIL
    try:
        canvas_size = 500
        grid_size = 250
        collage = Image.new("RGB", (canvas_size, canvas_size), (30, 30, 45))

        positions = [(0, 0), (grid_size, 0), (0, grid_size), (grid_size, grid_size)]

        for i in range(4):
            c_path = cover_paths[i % len(cover_paths)]
            with Image.open(c_path) as img:
                img_resized = img.resize((grid_size, grid_size), Image.Resampling.LANCZOS)
                collage.paste(img_resized, positions[i])

        buf = io.BytesIO()
        collage.save(buf, format="JPEG", quality=85)
        return Response(content=buf.getvalue(), media_type="image/jpeg")
    except Exception:
        return Response(content=DEFAULT_PLAYLIST_SVG, media_type="image/svg+xml")
