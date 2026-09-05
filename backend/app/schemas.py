from datetime import datetime
from typing import Optional, List
from pydantic import BaseModel, ConfigDict

class SongBase(BaseModel):
    title: str
    artist: str
    album: str
    album_artist: Optional[str] = None
    genre: Optional[str] = None
    year: Optional[int] = None
    track_number: Optional[int] = None
    disc_number: Optional[int] = None
    duration: float
    bitrate: Optional[int] = 0
    sample_rate: Optional[int] = 0
    codec: Optional[str] = ""
    file_size: int
    cover_art_path: Optional[str] = None

class SongResponse(SongBase):
    id: int
    file_path: str
    created_at: datetime
    updated_at: datetime
    is_favorite: Optional[bool] = False

    model_config = ConfigDict(from_attributes=True)

class SongListResponse(BaseModel):
    total: int
    page: int
    limit: int
    songs: List[SongResponse]

class ArtistResponse(BaseModel):
    id: int
    name: str
    song_count: int
    album_count: int

    model_config = ConfigDict(from_attributes=True)

class AlbumResponse(BaseModel):
    id: int
    title: str
    artist: str
    year: Optional[int] = None
    cover_art_path: Optional[str] = None
    song_count: int

    model_config = ConfigDict(from_attributes=True)

class SearchResponse(BaseModel):
    songs: List[SongResponse]
    artists: List[ArtistResponse]
    albums: List[AlbumResponse]

class PlaylistCreate(BaseModel):
    name: str

class PlaylistUpdate(BaseModel):
    name: str

class PlaylistResponse(BaseModel):
    id: int
    name: str
    song_count: int = 0
    is_system: bool = False
    created_at: datetime

    model_config = ConfigDict(from_attributes=True)

class PlaylistDetailResponse(PlaylistResponse):
    songs: List[SongResponse]

class PlaylistBatchSongs(BaseModel):
    song_ids: List[int]

class PlaylistReorder(BaseModel):
    song_ids: List[int]

class LyricLine(BaseModel):
    time: float # in seconds
    text: str

class LyricResponse(BaseModel):
    song_id: int
    lyrics_source: str # 'db', 'lrc', 'embedded', 'manual', 'lrclib', 'unavailable'
    plain_lyrics: Optional[str] = None
    timed_lyrics: List[LyricLine] = []
    is_synced: bool = False
    language: Optional[str] = None
    offset: int = 0 # in milliseconds
    is_manual: bool = False
    provider: Optional[str] = None
    match_confidence: Optional[float] = 1.0
    fetch_timestamp: Optional[datetime] = None
    updated_at: Optional[datetime] = None

class LyricCreate(BaseModel):
    lrc_content: str
    offset: Optional[int] = 0

class LyricOffsetUpdate(BaseModel):
    offset: int # in milliseconds


class SystemStatusResponse(BaseModel):
    hdd_connected: bool
    music_path: str
    readable: bool
    total_files: int
    db_status: str
    total_songs_in_db: int
    total_artists_in_db: int
    total_albums_in_db: int

class ScanStatusResponse(BaseModel):
    status: str
    total_files: int
    scanned_files: int
    current_file: Optional[str] = None
    progress_percentage: float
    last_scan_time: Optional[str] = None
    total_songs: int
    total_artists: int
    total_albums: int

class DirectoryUpdateRequest(BaseModel):
    path: str
    rescan: Optional[bool] = True

class DirectoryItem(BaseModel):
    name: str
    path: str
    is_dir: bool
    has_music: Optional[bool] = False

class DirectoryBrowseResponse(BaseModel):
    current_path: str
    parent_path: Optional[str] = None
    items: List[DirectoryItem]

class LyricLine(BaseModel):
    time: float # in seconds
    text: str

class LyricResponse(BaseModel):
    song_id: int
    lyrics_source: str # 'db', 'lrc', 'embedded', 'manual', 'unavailable'
    plain_lyrics: Optional[str] = None
    timed_lyrics: List[LyricLine] = []
    is_synced: bool = False
    language: Optional[str] = None
    offset: int = 0 # in milliseconds
    is_manual: bool = False
    updated_at: Optional[datetime] = None

class LyricCreate(BaseModel):
    lrc_content: str
    offset: Optional[int] = 0

class LyricOffsetUpdate(BaseModel):
    offset: int # in milliseconds


