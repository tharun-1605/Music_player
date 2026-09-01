from datetime import datetime
from sqlalchemy import Column, Integer, String, Float, DateTime, ForeignKey, Text
from sqlalchemy.orm import relationship
from app.database import Base

class Song(Base):
    __tablename__ = "songs"

    id = Column(Integer, primary_key=True, index=True, autoincrement=True)
    title = Column(String, index=True, nullable=False, default="Unknown Title")
    artist = Column(String, index=True, nullable=False, default="Unknown Artist")
    album = Column(String, index=True, nullable=False, default="Unknown Album")
    album_artist = Column(String, default="Unknown Artist")
    genre = Column(String, index=True, default="Unknown")
    year = Column(Integer, nullable=True)
    track_number = Column(Integer, nullable=True)
    disc_number = Column(Integer, nullable=True)
    duration = Column(Float, default=0.0)
    bitrate = Column(Integer, default=0)
    sample_rate = Column(Integer, default=0)
    codec = Column(String, default="")
    file_size = Column(Integer, default=0)
    file_path = Column(String, unique=True, index=True, nullable=False)
    cover_art_path = Column(String, nullable=True)
    mtime = Column(Float, default=0.0)
    created_at = Column(DateTime, default=datetime.utcnow)
    updated_at = Column(DateTime, default=datetime.utcnow, onupdate=datetime.utcnow)

class Artist(Base):
    __tablename__ = "artists"

    id = Column(Integer, primary_key=True, index=True, autoincrement=True)
    name = Column(String, unique=True, index=True, nullable=False)
    song_count = Column(Integer, default=0)
    album_count = Column(Integer, default=0)

class Album(Base):
    __tablename__ = "albums"

    id = Column(Integer, primary_key=True, index=True, autoincrement=True)
    title = Column(String, index=True, nullable=False)
    artist = Column(String, index=True, nullable=False, default="Unknown Artist")
    year = Column(Integer, nullable=True)
    cover_art_path = Column(String, nullable=True)
    song_count = Column(Integer, default=0)

class Playlist(Base):
    __tablename__ = "playlists"

    id = Column(Integer, primary_key=True, index=True, autoincrement=True)
    name = Column(String, unique=True, nullable=False)
    created_at = Column(DateTime, default=datetime.utcnow)

    songs = relationship("PlaylistSong", back_populates="playlist", cascade="all, delete-orphan")

class PlaylistSong(Base):
    __tablename__ = "playlist_songs"

    id = Column(Integer, primary_key=True, index=True, autoincrement=True)
    playlist_id = Column(Integer, ForeignKey("playlists.id", ondelete="CASCADE"), nullable=False)
    song_id = Column(Integer, ForeignKey("songs.id", ondelete="CASCADE"), nullable=False)
    position = Column(Integer, nullable=False, default=0)
    added_at = Column(DateTime, default=datetime.utcnow)

    playlist = relationship("Playlist", back_populates="songs")
    song = relationship("Song")

class Favorite(Base):
    __tablename__ = "favorites"

    id = Column(Integer, primary_key=True, index=True, autoincrement=True)
    song_id = Column(Integer, ForeignKey("songs.id", ondelete="CASCADE"), unique=True, nullable=False)
    created_at = Column(DateTime, default=datetime.utcnow)

    song = relationship("Song")

class PlayHistory(Base):
    __tablename__ = "play_history"

    id = Column(Integer, primary_key=True, index=True, autoincrement=True)
    song_id = Column(Integer, ForeignKey("songs.id", ondelete="CASCADE"), nullable=False)
    played_at = Column(DateTime, default=datetime.utcnow)

    song = relationship("Song")
