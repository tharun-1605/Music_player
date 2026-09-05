import os
import time
import threading
import re
from collections import Counter
from datetime import datetime
from pathlib import Path
from typing import Dict, Any, List
from sqlalchemy.orm import Session
from sqlalchemy import func

from app.config import settings
from app.database import SessionLocal
from app.models import Song, Artist, Album
from app.metadata import extract_metadata

SUPPORTED_EXTENSIONS = {'.flac', '.m4a', '.opus', '.wav', '.mp3', '.aac', '.ogg', '.mp4'}

KNOWN_COMPOSERS = [
    'A.R. Rahman', 'AR Rahman', 'A. R. Rahman', 'Harris Jayaraj', 'Yuvan Shankar Raja',
    'Anirudh Ravichander', 'Anirudh', 'G. V. Prakash Kumar', 'G.V. Prakash Kumar',
    'G.V. Prakash', 'G. V. Prakash', 'Hiphop Tamizha', 'Santhosh Narayanan', 'Devi Sri Prasad',
    'D. Imman', 'Ilaiyaraaja', 'Ilayaraja', 'Vidyasagar', 'Karthik Raja',
    'Vijay Antony', 'Ghibran', 'Sam C.S.', 'Govind Vasantha', 'Sai Abhyankkar',
    'Sean Roldan', 'Sid Sriram', 'Nivas K. Prasanna', 'Deva', 'S. A. Rajkumar', 'Sirpy'
]

def normalize_movie_album(raw_album: str) -> str:
    if not raw_album or raw_album == 'Unknown Album':
        return 'Unknown Album'

    title = raw_album.strip()

    m = re.search(r'(?:-\s*)?(?:From|from)\s+[\"“\']([^\"”\']+)[\"“\']', title)
    if m:
        return m.group(1).strip()

    m2 = re.search(r'\bFrom\s+([A-Za-z0-9\s]+?)(?:\s*-\s*Single|\s*\[|\s*\(|$)', title)
    if m2 and m2.group(1).strip():
        val = m2.group(1).strip()
        if len(val) > 1 and val not in ['Think Indie', 'YouTube']:
            return val

    patterns_to_remove = [
        r'\s*\((?:Original|Orignal)\s+(?:Motion\s+Picture\s+)?Soundtrack.*?\)',
        r'\s*\[(?:Original|Orignal)\s+(?:Motion\s+Picture\s+)?Soundtrack.*?\]',
        r'\s*\((?:Original|Orignal)\s+Soundtrack.*?\)',
        r'\s*\[(?:Original|Orignal)\s+Soundtrack.*?\]',
        r'\s*\((?:Original|Orignal)\s+(?:Background\s+)?Score.*?\)',
        r'\s*\[(?:Original|Orignal)\s+(?:Background\s+)?Score.*?\]',
        r'\s*-\s*Side\s+[A-Z].*',
        r'\s*-\s*Bonus\s+Tracks.*',
        r'\s*,\s*Bonus\s+Tracks.*',
        r'\s*-\s*Single.*',
        r'\s*\((?:OST|ost)\)',
        r'\s*\[(?:OST|ost)\]',
        r'\s*\[Tamil\]',
        r'\s*\[Telugu\]',
        r'\s*\[Hindi\]',
        r'\s*\(Tamil\)',
        r'\s*\(Telugu\)',
        r'\s*\(Hindi\)',
        r'\s*\(\d{4}\)',
    ]

    clean = title
    for p in patterns_to_remove:
        clean = re.sub(p, '', clean, flags=re.IGNORECASE)

    clean = clean.strip(' -')
    return clean if clean else title

def extract_primary_artist(artist_list: List[str]) -> str:
    composer_counts = Counter()
    for a_str in artist_list:
        if not a_str:
            continue
        for comp in KNOWN_COMPOSERS:
            pattern = r'(?<![A-Za-z0-9])' + re.escape(comp) + r'(?![A-Za-z0-9])'
            if re.search(pattern, a_str, re.IGNORECASE):
                canonical = comp
                if 'rahman' in comp.lower():
                    canonical = 'A.R. Rahman'
                elif 'g.v.' in comp.lower() or 'g. v.' in comp.lower():
                    canonical = 'G. V. Prakash Kumar'
                elif 'ilaiyaraaja' in comp.lower() or 'ilayaraja' in comp.lower():
                    canonical = 'Ilaiyaraaja'
                composer_counts[canonical] += 1

    if composer_counts:
        return composer_counts.most_common(1)[0][0]

    primaries = []
    for a_str in artist_list:
        if not a_str or a_str == 'Unknown Artist':
            continue
        first = re.split(r'[,;&]|feat\.|ft\.|with', a_str, flags=re.IGNORECASE)[0].strip()
        if first:
            primaries.append(first)

    if primaries:
        return Counter(primaries).most_common(1)[0][0]
    return 'Unknown Artist'

class LibraryScanner:
    def __init__(self):
        self.status = "idle"
        self.total_files = 0
        self.scanned_files = 0
        self.current_file = None
        self.progress_percentage = 0.0
        self.last_scan_time = None
        self._lock = threading.Lock()

    def get_status(self, db: Session) -> Dict[str, Any]:
        with self._lock:
            total_songs = db.query(Song).count()
            total_artists = db.query(Artist).count()
            total_albums = db.query(Album).count()
            return {
                "status": self.status,
                "total_files": self.total_files,
                "scanned_files": self.scanned_files,
                "current_file": self.current_file,
                "progress_percentage": self.progress_percentage,
                "last_scan_time": self.last_scan_time,
                "total_songs": total_songs,
                "total_artists": total_artists,
                "total_albums": total_albums
            }

    def start_scan(self):
        with self._lock:
            if self.status == "scanning":
                return False
            self.status = "scanning"
            self.scanned_files = 0
            self.progress_percentage = 0.0

        thread = threading.Thread(target=self._run_scan_thread, daemon=True)
        thread.start()
        return True

    def _run_scan_thread(self):
        db = SessionLocal()
        try:
            library_dir = Path(settings.MUSIC_LIBRARY_PATH)
            print(f"\n[LibraryScanner] Starting scan of music library at: {library_dir}")
            if not library_dir.exists() or not library_dir.is_dir():
                print(f"[LibraryScanner] ERROR: Music directory '{library_dir}' does not exist or is not a directory.")
                with self._lock:
                    self.status = "failed"
                return

            found_files: List[Path] = []
            for root, _, files in os.walk(library_dir):
                for f in files:
                    p = Path(root) / f
                    if p.suffix.lower() in SUPPORTED_EXTENSIONS:
                        found_files.append(p)

            total = len(found_files)
            print(f"[LibraryScanner] Found {total} audio files. Processing metadata...")
            with self._lock:
                self.total_files = total

            existing_songs = {s.file_path: (s.id, s.mtime) for s in db.query(Song.id, Song.file_path, Song.mtime).all()}
            found_paths_set = set(str(p) for p in found_files)

            missing_paths = set(existing_songs.keys()) - found_paths_set
            if missing_paths:
                print(f"[LibraryScanner] Cleaning up {len(missing_paths)} removed files from database...")
                db.query(Song).filter(Song.file_path.in_(missing_paths)).delete(synchronize_session=False)
                db.commit()

            batch_size = 50
            pending_adds = []

            for idx, file_path_obj in enumerate(found_files):
                file_str = str(file_path_obj)
                with self._lock:
                    self.current_file = file_path_obj.name
                    self.scanned_files = idx + 1
                    self.progress_percentage = round(((idx + 1) / total) * 100, 1) if total > 0 else 100.0

                try:
                    current_mtime = file_path_obj.stat().st_mtime
                    if file_str in existing_songs:
                        song_id, db_mtime = existing_songs[file_str]
                        if abs((db_mtime or 0) - current_mtime) > 1.0:
                            meta = extract_metadata(file_str)
                            db.query(Song).filter(Song.id == song_id).update({
                                Song.title: meta["title"],
                                Song.artist: meta["artist"],
                                Song.album: meta["album"],
                                Song.album_artist: meta["album_artist"],
                                Song.genre: meta["genre"],
                                Song.year: meta["year"],
                                Song.track_number: meta["track_number"],
                                Song.disc_number: meta["disc_number"],
                                Song.duration: meta["duration"],
                                Song.bitrate: meta["bitrate"],
                                Song.sample_rate: meta["sample_rate"],
                                Song.codec: meta["codec"],
                                Song.file_size: meta["file_size"],
                                Song.cover_art_path: meta["cover_art_path"],
                                Song.mtime: current_mtime,
                                Song.updated_at: datetime.utcnow()
                            })
                    else:
                        meta = extract_metadata(file_str)
                        song = Song(
                            title=meta["title"],
                            artist=meta["artist"],
                            album=meta["album"],
                            album_artist=meta["album_artist"],
                            genre=meta["genre"],
                            year=meta["year"],
                            track_number=meta["track_number"],
                            disc_number=meta["disc_number"],
                            duration=meta["duration"],
                            bitrate=meta["bitrate"],
                            sample_rate=meta["sample_rate"],
                            codec=meta["codec"],
                            file_size=meta["file_size"],
                            file_path=file_str,
                            cover_art_path=meta["cover_art_path"],
                            mtime=current_mtime
                        )
                        pending_adds.append(song)

                    if len(pending_adds) >= batch_size:
                        db.add_all(pending_adds)
                        db.commit()
                        pending_adds = []

                except Exception as file_err:
                    continue

            if pending_adds:
                db.add_all(pending_adds)
                db.commit()

            self._rebuild_artists_and_albums(db)

            song_cnt = db.query(Song).count()
            artist_cnt = db.query(Artist).count()
            album_cnt = db.query(Album).count()
            print(f"[LibraryScanner] Scan completed! DB now contains {song_cnt} songs, {artist_cnt} artists, and {album_cnt} albums.\n")

            with self._lock:
                self.status = "completed"
                self.last_scan_time = datetime.utcnow().isoformat()
                self.current_file = None

        except Exception as scan_err:
            print(f"[LibraryScanner] ERROR during scan: {scan_err}")
            with self._lock:
                self.status = "failed"
        finally:
            db.close()


    def _rebuild_artists_and_albums(self, db: Session):
        db.query(Artist).delete()
        db.query(Album).delete()

        all_songs = db.query(Song).all()
        movie_groups: Dict[str, List[Song]] = {}

        for song in all_songs:
            norm_title = normalize_movie_album(song.album)
            movie_groups.setdefault(norm_title, []).append(song)

        albums_to_add = []
        for movie_title, songs_in_album in movie_groups.items():
            if not movie_title:
                continue

            artist_list = [s.album_artist for s in songs_in_album if s.album_artist] + [s.artist for s in songs_in_album if s.artist]
            rep_artist = extract_primary_artist(artist_list)

            years = [s.year for s in songs_in_album if s.year is not None]
            min_year = min(years) if years else None

            covers = [s.cover_art_path for s in songs_in_album if s.cover_art_path]
            rep_cover = covers[0] if covers else None

            albums_to_add.append(
                Album(
                    title=movie_title,
                    artist=rep_artist,
                    year=min_year,
                    cover_art_path=rep_cover,
                    song_count=len(songs_in_album)
                )
            )

        db.add_all(albums_to_add)

        artist_counts = db.query(
            Song.artist,
            func.count(Song.id),
            func.count(func.distinct(Song.album))
        ).group_by(Song.artist).all()

        artists_to_add = [
            Artist(name=a[0], song_count=a[1], album_count=a[2])
            for a in artist_counts if a[0]
        ]
        db.add_all(artists_to_add)
        db.commit()

scanner_instance = LibraryScanner()
