import hashlib
import os
from pathlib import Path
from typing import Dict, Any, Optional
import mutagen
from mutagen.flac import FLAC
from mutagen.mp4 import MP4
from mutagen.oggvorbis import OggVorbis
from mutagen.oggopus import OggOpus
from mutagen.mp3 import MP3
from mutagen.id3 import ID3, APIC
from app.config import settings

def _extract_cover_art(audio_obj, file_path: str) -> Optional[str]:
    """Extract embedded artwork bytes and cache as JPG/PNG file."""
    image_bytes = None

    try:
        # FLAC
        if isinstance(audio_obj, FLAC) and audio_obj.pictures:
            image_bytes = audio_obj.pictures[0].data
        # MP3 / ID3
        elif hasattr(audio_obj, 'tags') and audio_obj.tags:
            tags = audio_obj.tags
            if isinstance(tags, ID3):
                for tag in tags.values():
                    if isinstance(tag, APIC):
                        image_bytes = tag.data
                        break
        # MP4 / M4A
        if not image_bytes and isinstance(audio_obj, MP4):
            covs = audio_obj.tags.get('covr') if audio_obj.tags else None
            if covs:
                image_bytes = bytes(covs[0])
        # Generic mutagen File fallback
        if not image_bytes and hasattr(audio_obj, 'pictures') and audio_obj.pictures:
            image_bytes = audio_obj.pictures[0].data

    except Exception:
        pass

    if image_bytes:
        img_hash = hashlib.md5(image_bytes).hexdigest()
        cover_filename = f"{img_hash}.jpg"
        cover_file_path = settings.CACHE_DIR / cover_filename
        if not cover_file_path.exists():
            try:
                with open(cover_file_path, "wb") as f:
                    f.write(image_bytes)
            except Exception:
                return None
        return cover_filename
    return None

def extract_metadata(file_path: str) -> Dict[str, Any]:
    path = Path(file_path)
    file_size = path.stat().st_size
    mtime = path.stat().st_mtime
    ext = path.suffix.lower()

    # Defaults
    title = path.stem
    artist = "Unknown Artist"
    album = "Unknown Album"
    album_artist = "Unknown Artist"
    genre = "Unknown"
    year = None
    track_number = None
    disc_number = None
    duration = 0.0
    bitrate = 0
    sample_rate = 0
    codec = ext.lstrip('.').upper()
    cover_art_path = None

    try:
        audio = mutagen.File(file_path)
        if audio is not None:
            # Audio Properties
            if hasattr(audio, 'info') and audio.info is not None:
                duration = getattr(audio.info, 'length', 0.0) or 0.0
                bitrate = getattr(audio.info, 'bitrate', 0) or 0
                sample_rate = getattr(audio.info, 'sample_rate', 0) or 0

            # Cover Art Extraction
            cover_art_path = _extract_cover_art(audio, file_path)

            # Metadata Tags
            tags = audio.tags or {}
            
            # Helper tag retriever
            def get_tag(keys):
                for k in keys:
                    if k in tags:
                        val = tags[k]
                        if isinstance(val, list) and val:
                            return str(val[0])
                        elif isinstance(val, (str, int)):
                            return str(val)
                return None

            # FLAC / OggVorbis / Opus tags
            if isinstance(audio, (FLAC, OggVorbis, OggOpus)):
                t_title = get_tag(['title', 'TITLE'])
                if t_title: title = t_title
                t_artist = get_tag(['artist', 'ARTIST'])
                if t_artist: artist = t_artist
                t_album = get_tag(['album', 'ALBUM'])
                if t_album: album = t_album
                t_album_artist = get_tag(['albumartist', 'ALBUMARTIST', 'album artist', 'ALBUM ARTIST'])
                if t_album_artist: album_artist = t_album_artist
                else: album_artist = artist
                t_genre = get_tag(['genre', 'GENRE'])
                if t_genre: genre = t_genre
                t_date = get_tag(['date', 'DATE', 'year', 'YEAR'])
                if t_date:
                    try:
                        year = int(t_date[:4])
                    except ValueError:
                        pass
                t_track = get_tag(['tracknumber', 'TRACKNUMBER'])
                if t_track:
                    try:
                        track_number = int(t_track.split('/')[0])
                    except (ValueError, AttributeError):
                        pass
                t_disc = get_tag(['discnumber', 'DISCNUMBER'])
                if t_disc:
                    try:
                        disc_number = int(t_disc.split('/')[0])
                    except (ValueError, AttributeError):
                        pass

            # MP4 / M4A tags
            elif isinstance(audio, MP4):
                if tags:
                    if '\xa9nam' in tags and tags['\xa9nam']:
                        title = str(tags['\xa9nam'][0])
                    if '\xa9ART' in tags and tags['\xa9ART']:
                        artist = str(tags['\xa9ART'][0])
                    if '\xa9alb' in tags and tags['\xa9alb']:
                        album = str(tags['\xa9alb'][0])
                    if 'aART' in tags and tags['aART']:
                        album_artist = str(tags['aART'][0])
                    else:
                        album_artist = artist
                    if '\xa9gen' in tags and tags['\xa9gen']:
                        genre = str(tags['\xa9gen'][0])
                    if '\xa9day' in tags and tags['\xa9day']:
                        try:
                            year = int(str(tags['\xa9day'][0])[:4])
                        except ValueError:
                            pass
                    if 'trkn' in tags and tags['trkn']:
                        try:
                            track_number = int(tags['trkn'][0][0])
                        except (IndexError, TypeError, ValueError):
                            pass
                    if 'disk' in tags and tags['disk']:
                        try:
                            disc_number = int(tags['disk'][0][0])
                        except (IndexError, TypeError, ValueError):
                            pass

            # MP3 ID3 / EasyID3
            elif isinstance(audio, MP3) or hasattr(tags, 'get'):
                t_title = get_tag(['TIT2', 'title'])
                if t_title: title = t_title
                t_artist = get_tag(['TPE1', 'artist'])
                if t_artist: artist = t_artist
                t_album = get_tag(['TALB', 'album'])
                if t_album: album = t_album
                t_album_artist = get_tag(['TPE2', 'albumartist'])
                if t_album_artist: album_artist = t_album_artist
                else: album_artist = artist
                t_genre = get_tag(['TCON', 'genre'])
                if t_genre: genre = t_genre
                t_date = get_tag(['TDRC', 'TYER', 'date', 'year'])
                if t_date:
                    try:
                        year = int(str(t_date)[:4])
                    except ValueError:
                        pass
                t_track = get_tag(['TRCK', 'tracknumber'])
                if t_track:
                    try:
                        track_number = int(str(t_track).split('/')[0])
                    except (ValueError, AttributeError):
                        pass

    except Exception:
        pass

    # Infer artist from directory structure if artist is unknown
    if artist == "Unknown Artist" or not artist:
        parts = path.parts
        for part in parts:
            if "Discography" in part:
                artist = part.replace("Discography", "").strip()
                break

    return {
        "title": title or path.stem,
        "artist": artist or "Unknown Artist",
        "album": album or "Unknown Album",
        "album_artist": album_artist or artist or "Unknown Artist",
        "genre": genre or "Unknown",
        "year": year,
        "track_number": track_number,
        "disc_number": disc_number,
        "duration": float(duration),
        "bitrate": int(bitrate),
        "sample_rate": int(sample_rate),
        "codec": codec,
        "file_size": file_size,
        "file_path": str(path),
        "cover_art_path": cover_art_path,
        "mtime": mtime
    }
