import json
import re
from datetime import datetime
from pathlib import Path
from typing import Optional, List, Tuple
from fastapi import APIRouter, Depends, HTTPException, status
from sqlalchemy.orm import Session

from app.database import get_db
from app.models import Song, Lyric
from app.schemas import LyricResponse, LyricCreate, LyricOffsetUpdate, LyricLine
from app.metadata import extract_embedded_lyrics
from app.lyrics_providers import AVAILABLE_LYRICS_PROVIDERS

router = APIRouter(prefix="/api/songs", tags=["Lyrics"])

def parse_lrc_content(raw_text: str, override_offset: int = 0) -> Tuple[List[dict], bool, int, str]:
    if not raw_text or not raw_text.strip():
        return [], False, override_offset, ""

    raw_text = raw_text.lstrip('\ufeff')
    lines = raw_text.splitlines()
    timed_lines = []
    plain_lines = []
    global_offset = override_offset

    offset_match = re.search(r'\[offset:\s*([+-]?\d+)\]', raw_text, re.IGNORECASE)
    if offset_match:
        try:
            global_offset += int(offset_match.group(1))
        except ValueError:
            pass

    ts_regex = re.compile(r'\[(\d{1,3}):(\d{2})(?:[.:](\d{1,3}))?\]')
    meta_regex = re.compile(r'^\[(ti|ar|al|au|by|offset|re|ve|length):', re.IGNORECASE)

    for line in lines:
        line_str = line.strip()
        if not line_str:
            continue

        if meta_regex.match(line_str):
            continue

        matches = list(ts_regex.finditer(line_str))
        if matches:
            text_content = ts_regex.sub('', line_str).strip()
            for m in matches:
                mins = int(m.group(1))
                secs = int(m.group(2))
                frac_str = m.group(3)
                if frac_str:
                    frac = int(frac_str) / (10 ** len(frac_str))
                else:
                    frac = 0.0

                total_sec = mins * 60 + secs + frac
                total_sec += global_offset / 1000.0
                if total_sec < 0:
                    total_sec = 0.0

                timed_lines.append({
                    "time": round(total_sec, 3),
                    "text": text_content
                })
        else:
            plain_lines.append(line_str)

    if timed_lines:
        timed_lines.sort(key=lambda x: x["time"])
        return timed_lines, True, global_offset, raw_text
    else:
        plain_text = "\n".join(plain_lines)
        return [], False, global_offset, plain_text

def _find_local_lrc_file(audio_path_str: str, song_title: str) -> Optional[Path]:
    audio_path = Path(audio_path_str)
    parent_dir = audio_path.parent
    if not parent_dir.exists():
        return None

    candidate1 = audio_path.with_suffix('.lrc')
    if candidate1.exists():
        return candidate1

    candidate2 = parent_dir / f"{song_title}.lrc"
    if candidate2.exists():
        return candidate2

    for file in parent_dir.glob("*.lrc"):
        if file.stem.lower() == audio_path.stem.lower() or file.stem.lower() == song_title.lower():
            return file

    return None

@router.get("/{song_id}/lyrics", response_model=LyricResponse)
async def get_song_lyrics(song_id: int, db: Session = Depends(get_db)):
    # 1. Lookup in Database first
    db_lyric = db.query(Lyric).filter(Lyric.song_id == song_id).first()
    if db_lyric:
        timed_list = []
        if db_lyric.timed_lyrics:
            try:
                timed_list = [LyricLine(**item) for item in json.loads(db_lyric.timed_lyrics)]
            except Exception:
                timed_list = []
        return LyricResponse(
            song_id=song_id,
            lyrics_source=db_lyric.lyrics_source,
            plain_lyrics=db_lyric.plain_lyrics,
            timed_lyrics=timed_list,
            is_synced=len(timed_list) > 0,
            language=db_lyric.language,
            offset=db_lyric.offset,
            is_manual=bool(db_lyric.is_manual),
            provider=db_lyric.provider,
            match_confidence=db_lyric.match_confidence,
            fetch_timestamp=db_lyric.fetch_timestamp,
            updated_at=db_lyric.updated_at
        )

    song = db.query(Song).filter(Song.id == song_id).first()
    if not song:
        return LyricResponse(
            song_id=song_id,
            lyrics_source="unavailable",
            plain_lyrics="Lyrics unavailable",
            timed_lyrics=[],
            is_synced=False,
            offset=0,
            is_manual=False
        )
    # 2. Lookup Local .lrc File
    lrc_path = _find_local_lrc_file(song.file_path, song.title)
    if lrc_path:
        try:
            content = lrc_path.read_text(encoding='utf-8', errors='ignore')
            timed, is_synced, offset, plain = parse_lrc_content(content)
            timed_lines = [LyricLine(**item) for item in timed]
            
            # Save to DB cache
            db_lyric = Lyric(
                song_id=song_id,
                lyrics_source="lrc",
                plain_lyrics=plain,
                timed_lyrics=json.dumps(timed) if timed else None,
                offset=offset,
                is_manual=0,
                provider="local_lrc",
                match_confidence=1.0,
                fetch_timestamp=datetime.utcnow()
            )
            db.add(db_lyric)
            db.commit()
            db.refresh(db_lyric)

            return LyricResponse(
                song_id=song_id,
                lyrics_source="lrc",
                plain_lyrics=plain,
                timed_lyrics=timed_lines,
                is_synced=is_synced,
                offset=offset,
                is_manual=False,
                provider="local_lrc",
                match_confidence=1.0,
                fetch_timestamp=db_lyric.fetch_timestamp
            )
        except Exception:
            pass

    # 3. Lookup Embedded Metadata
    embedded_raw = extract_embedded_lyrics(song.file_path)
    if embedded_raw:
        timed, is_synced, offset, plain = parse_lrc_content(embedded_raw)
        timed_lines = [LyricLine(**item) for item in timed]

        # Save to DB cache
        db_lyric = Lyric(
            song_id=song_id,
            lyrics_source="embedded",
            plain_lyrics=plain,
            timed_lyrics=json.dumps(timed) if timed else None,
            offset=offset,
            is_manual=0,
            provider="embedded_tags",
            match_confidence=1.0,
            fetch_timestamp=datetime.utcnow()
        )
        db.add(db_lyric)
        db.commit()
        db.refresh(db_lyric)

        return LyricResponse(
            song_id=song_id,
            lyrics_source="embedded",
            plain_lyrics=plain,
            timed_lyrics=timed_lines,
            is_synced=is_synced,
            offset=offset,
            is_manual=False,
            provider="embedded_tags",
            match_confidence=1.0,
            fetch_timestamp=db_lyric.fetch_timestamp
        )

    # 4. Query External Lyrics Providers (LRCLIB, etc.)
    for provider in AVAILABLE_LYRICS_PROVIDERS:
        try:
            p_res = await provider.search_lyrics(song.title, song.artist, song.album, song.duration)
            if p_res and p_res.get("raw_lrc"):
                raw_lrc = p_res["raw_lrc"]
                timed, is_synced, offset, plain = parse_lrc_content(raw_lrc)
                timed_lines = [LyricLine(**item) for item in timed]

                db_lyric = Lyric(
                    song_id=song_id,
                    lyrics_source=provider.name.lower(),
                    plain_lyrics=plain or p_res.get("plain_text"),
                    timed_lyrics=json.dumps(timed) if timed else None,
                    offset=offset,
                    is_manual=0,
                    provider=provider.name,
                    match_confidence=p_res.get("confidence", 0.9),
                    fetch_timestamp=datetime.utcnow()
                )
                db.add(db_lyric)
                db.commit()
                db.refresh(db_lyric)

                return LyricResponse(
                    song_id=song_id,
                    lyrics_source=provider.name.lower(),
                    plain_lyrics=plain or p_res.get("plain_text"),
                    timed_lyrics=timed_lines,
                    is_synced=is_synced,
                    offset=offset,
                    is_manual=False,
                    provider=provider.name,
                    match_confidence=p_res.get("confidence", 0.9),
                    fetch_timestamp=db_lyric.fetch_timestamp
                )
        except Exception:
            pass

    # 5. Fallback: Lyrics Unavailable
    return LyricResponse(
        song_id=song_id,
        lyrics_source="unavailable",
        plain_lyrics="Lyrics unavailable",
        timed_lyrics=[],
        is_synced=False,
        offset=0,
        is_manual=False
    )

@router.post("/{song_id}/lyrics/refetch", response_model=LyricResponse)
async def refetch_song_lyrics(song_id: int, db: Session = Depends(get_db)):
    song = db.query(Song).filter(Song.id == song_id).first()
    if not song:
        return LyricResponse(
            song_id=song_id,
            lyrics_source="unavailable",
            plain_lyrics="Lyrics unavailable",
            timed_lyrics=[],
            is_synced=False,
            offset=0,
            is_manual=False
        )

    # Delete existing non-manual lyrics cache if present
    db_lyric = db.query(Lyric).filter(Lyric.song_id == song_id).first()
    if db_lyric:
        db.delete(db_lyric)
        db.commit()

    # Force query external providers
    for provider in AVAILABLE_LYRICS_PROVIDERS:
        try:
            p_res = await provider.search_lyrics(song.title, song.artist, song.album, song.duration)
            if p_res and p_res.get("raw_lrc"):
                raw_lrc = p_res["raw_lrc"]
                timed, is_synced, offset, plain = parse_lrc_content(raw_lrc)
                timed_lines = [LyricLine(**item) for item in timed]

                db_lyric = Lyric(
                    song_id=song_id,
                    lyrics_source=provider.name.lower(),
                    plain_lyrics=plain or p_res.get("plain_text"),
                    timed_lyrics=json.dumps(timed) if timed else None,
                    offset=offset,
                    is_manual=0,
                    provider=provider.name,
                    match_confidence=p_res.get("confidence", 0.9),
                    fetch_timestamp=datetime.utcnow()
                )
                db.add(db_lyric)
                db.commit()
                db.refresh(db_lyric)

                return LyricResponse(
                    song_id=song_id,
                    lyrics_source=provider.name.lower(),
                    plain_lyrics=plain or p_res.get("plain_text"),
                    timed_lyrics=timed_lines,
                    is_synced=is_synced,
                    offset=offset,
                    is_manual=False,
                    provider=provider.name,
                    match_confidence=p_res.get("confidence", 0.9),
                    fetch_timestamp=db_lyric.fetch_timestamp
                )
        except Exception:
            pass

    return LyricResponse(
        song_id=song_id,
        lyrics_source="unavailable",
        plain_lyrics="Lyrics unavailable",
        timed_lyrics=[],
        is_synced=False,
        offset=0,
        is_manual=False
    )

@router.post("/{song_id}/lyrics", response_model=LyricResponse)
def save_song_lyrics(song_id: int, payload: LyricCreate, db: Session = Depends(get_db)):
    song = db.query(Song).filter(Song.id == song_id).first()
    if not song:
        song = Song(
            id=song_id,
            title=f"Song #{song_id}",
            artist="Unknown Artist",
            album="Unknown Album",
            file_path=f"virtual_path_{song_id}.mp3"
        )
        db.add(song)
        db.commit()
        db.refresh(song)

    timed, is_synced, offset, plain = parse_lrc_content(payload.lrc_content, override_offset=payload.offset or 0)
    timed_json = json.dumps(timed) if timed else None

    db_lyric = db.query(Lyric).filter(Lyric.song_id == song_id).first()
    saved_plain = plain if plain else payload.lrc_content
    if db_lyric:
        db_lyric.lyrics_source = "manual"
        db_lyric.plain_lyrics = saved_plain
        db_lyric.timed_lyrics = timed_json
        db_lyric.offset = offset
        db_lyric.is_manual = 1
        db_lyric.provider = "manual_input"
        db_lyric.fetch_timestamp = datetime.utcnow()
    else:
        db_lyric = Lyric(
            song_id=song_id,
            lyrics_source="manual",
            plain_lyrics=saved_plain,
            timed_lyrics=timed_json,
            offset=offset,
            is_manual=1,
            provider="manual_input",
            fetch_timestamp=datetime.utcnow()
        )
        db.add(db_lyric)

    db.commit()
    db.refresh(db_lyric)

    try:
        if song.file_path:
            lrc_file_path = Path(song.file_path).with_suffix('.lrc')
            lrc_file_path.write_text(payload.lrc_content, encoding='utf-8')
    except Exception:
        pass

    timed_lines = [LyricLine(**item) for item in timed]
    return LyricResponse(
        song_id=song_id,
        lyrics_source="manual",
        plain_lyrics=saved_plain,
        timed_lyrics=timed_lines,
        is_synced=is_synced,
        offset=offset,
        is_manual=True,
        provider="manual_input",
        fetch_timestamp=db_lyric.fetch_timestamp,
        updated_at=db_lyric.updated_at
    )

@router.patch("/{song_id}/lyrics/offset", response_model=LyricResponse)
async def update_lyrics_offset(song_id: int, payload: LyricOffsetUpdate, db: Session = Depends(get_db)):
    db_lyric = db.query(Lyric).filter(Lyric.song_id == song_id).first()
    if not db_lyric:
        current_res = await get_song_lyrics(song_id, db)
        if current_res.lyrics_source == "unavailable":
            raise HTTPException(status_code=404, detail="No lyrics found to update offset")

        lrc_lines = []
        for line in current_res.timed_lyrics:
            mins = int(line.time // 60)
            secs = line.time % 60
            lrc_lines.append(f"[{mins:02d}:{secs:06.3f}] {line.text}")
        lrc_text = "\n".join(lrc_lines) if lrc_lines else (current_res.plain_lyrics or "")
        
        return save_song_lyrics(song_id, LyricCreate(lrc_content=lrc_text, offset=payload.offset), db)

    db_lyric.offset = payload.offset
    db.commit()
    db.refresh(db_lyric)

    return await get_song_lyrics(song_id, db)

@router.delete("/{song_id}/lyrics", status_code=status.HTTP_204_NO_CONTENT)
def delete_song_lyrics(song_id: int, db: Session = Depends(get_db)):
    db_lyric = db.query(Lyric).filter(Lyric.song_id == song_id).first()
    if db_lyric:
        db.delete(db_lyric)
        db.commit()
    return None
