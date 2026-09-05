import os
import re
import json
import urllib.request
import urllib.parse
from pathlib import Path
from typing import Optional

CACHE_DIR = Path(__file__).resolve().parent.parent / "data" / "artist_images"

def _slugify(text: str) -> str:
    return re.sub(r'[^a-z0-9]+', '_', text.lower()).strip('_')

def get_artist_image_file(artist_name: str) -> Optional[Path]:
    if not artist_name or artist_name.strip() == "" or artist_name.lower() == "unknown artist":
        return None

    CACHE_DIR.mkdir(parents=True, exist_ok=True)
    clean_name = artist_name.strip()
    slug = _slugify(clean_name)
    cached_path = CACHE_DIR / f"{slug}.jpg"

    if cached_path.exists() and cached_path.stat().st_size > 0:
        return cached_path

    # Try Deezer Open API
    try:
        url = "https://api.deezer.com/search/artist?q=" + urllib.parse.quote(clean_name)
        req = urllib.request.Request(url, headers={"User-Agent": "Mozilla/5.0 (Windows NT 10.0; Win64; x64)"})
        with urllib.request.urlopen(req, timeout=5) as resp:
            data = json.loads(resp.read().decode('utf-8'))
            if data.get("data") and len(data["data"]) > 0:
                pic_url = data["data"][0].get("picture_big") or data["data"][0].get("picture_medium")
                if pic_url:
                    img_req = urllib.request.Request(pic_url, headers={"User-Agent": "Mozilla/5.0"})
                    with urllib.request.urlopen(img_req, timeout=8) as img_resp:
                        img_bytes = img_resp.read()
                        if len(img_bytes) > 0:
                            cached_path.write_bytes(img_bytes)
                            return cached_path
    except Exception as e:
        print(f"[ArtistImages] Deezer fetch failed for '{clean_name}': {e}")

    # Fallback: iTunes Open API
    try:
        url = "https://itunes.apple.com/search?term=" + urllib.parse.quote(clean_name) + "&entity=musicArtist"
        req = urllib.request.Request(url, headers={"User-Agent": "Mozilla/5.0"})
        with urllib.request.urlopen(req, timeout=5) as resp:
            data = json.loads(resp.read().decode('utf-8'))
            if data.get("results") and len(data["results"]) > 0:
                artist_info = data["results"][0]
                art_url = artist_info.get("primaryGenreName") # iTunes artist search
    except Exception:
        pass

    return None
