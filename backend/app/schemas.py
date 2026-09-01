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

class PlaylistResponse(BaseModel):
    id: int
    name: str
    song_count: int = 0
    created_at: datetime

    model_config = ConfigDict(from_attributes=True)

class PlaylistDetailResponse(PlaylistResponse):
    songs: List[SongResponse]

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
