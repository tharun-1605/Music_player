import os
import time
import pytest
from fastapi.testclient import TestClient
from app.main import app
from app.database import engine, Base
from app.config import settings

# Ensure tables exist before running test requests
Base.metadata.create_all(bind=engine)

client = TestClient(app)

def test_health_endpoint():
    response = client.get("/api/health")
    assert response.status_code == 200
    data = response.json()
    assert data["status"] == "ok"
    assert data["library"] == settings.MUSIC_LIBRARY_PATH

def test_system_status_endpoint():
    response = client.get("/api/system/status")
    assert response.status_code == 200
    data = response.json()
    assert "hdd_connected" in data
    expected_connected = os.path.exists(settings.MUSIC_LIBRARY_PATH)
    assert data["hdd_connected"] == expected_connected

def test_library_scan_and_indexing():
    if not os.path.exists(settings.MUSIC_LIBRARY_PATH):
        pytest.skip("External HDD not mounted")

    # Trigger scan
    scan_resp = client.post("/api/library/scan")
    assert scan_resp.status_code == 200

    # Wait for scan completion (up to 30 seconds for 1,009 files)
    completed = False
    for _ in range(60):
        time.sleep(0.5)
        status_resp = client.get("/api/library/status")
        data = status_resp.json()
        if data["status"] == "completed":
            completed = True
            assert data["total_songs"] > 0
            assert data["total_artists"] > 0
            assert data["total_albums"] > 0
            break

    assert completed is True, "Library scan did not finish within timeout"

def test_songs_list():
    response = client.get("/api/songs?limit=10")
    assert response.status_code == 200
    data = response.json()
    assert "total" in data
    assert "songs" in data

def test_artists_list():
    response = client.get("/api/artists")
    assert response.status_code == 200
    artists = response.json()
    assert isinstance(artists, list)

def test_albums_list():
    response = client.get("/api/albums")
    assert response.status_code == 200
    albums = response.json()
    assert isinstance(albums, list)

def test_search_endpoint():
    response = client.get("/api/search?q=a")
    assert response.status_code == 200
    data = response.json()
    assert "songs" in data
    assert "artists" in data
    assert "albums" in data

def test_audio_streaming_range_request():
    if not os.path.exists(settings.MUSIC_LIBRARY_PATH):
        pytest.skip("External HDD not mounted")

    songs_resp = client.get("/api/songs?limit=1")
    songs = songs_resp.json().get("songs", [])
    if not songs:
        pytest.skip("No songs in database to stream")

    song_id = songs[0]["id"]
    headers = {"Range": "bytes=0-1023"}
    stream_resp = client.get(f"/api/songs/{song_id}/stream", headers=headers)
    assert stream_resp.status_code == 206
    assert stream_resp.headers.get("Content-Range").startswith("bytes 0-1023/")
    assert len(stream_resp.content) == 1024

def test_invalid_song_id():
    response = client.get("/api/songs/9999999/stream")
    assert response.status_code == 404

def test_path_traversal_protection():
    from app.streaming import validate_safe_path
    with pytest.raises(Exception) as excinfo:
        validate_safe_path("/etc/passwd", settings.MUSIC_LIBRARY_PATH)
    assert excinfo.value.status_code in [403, 404]

def test_cover_art_endpoint():
    if not os.path.exists(settings.MUSIC_LIBRARY_PATH):
        pytest.skip("External HDD not mounted")

    songs_resp = client.get("/api/songs?limit=1")
    songs = songs_resp.json().get("songs", [])
    if not songs:
        pytest.skip("No songs in database")

    song_id = songs[0]["id"]
    cover_resp = client.get(f"/api/songs/{song_id}/cover")
    assert cover_resp.status_code == 200
    assert cover_resp.headers["content-type"] in ["image/jpeg", "image/png", "image/svg+xml"]
