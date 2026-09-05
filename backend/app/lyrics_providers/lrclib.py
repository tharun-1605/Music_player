import asyncio
import json
import urllib.parse
import urllib.request
from typing import Optional, Dict, Any
from app.lyrics_providers.base import BaseLyricsProvider

class LrclibProvider(BaseLyricsProvider):
    @property
    def name(self) -> str:
        return "LRCLIB"

    def _sync_fetch(self, url: str) -> Optional[dict]:
        req = urllib.request.Request(
            url,
            headers={
                "User-Agent": "LANMusicPlayer/1.0 (https://github.com/lan-music-player)"
            }
        )
        try:
            with urllib.request.urlopen(req, timeout=5) as resp:
                if resp.status == 200:
                    data = resp.read().decode("utf-8")
                    return json.loads(data)
        except Exception:
            pass
        return None

    async def search_lyrics(
        self,
        title: str,
        artist: str,
        album: str,
        duration: float,
    ) -> Optional[Dict[str, Any]]:
        # 1. Try Direct Match via GET /api/get
        params = {
            "track_name": title,
            "artist_name": artist,
        }
        if album and album != "Unknown Album":
            params["album_name"] = album
        if duration > 0:
            params["duration"] = int(duration)

        get_url = f"https://lrclib.net/api/get?{urllib.parse.urlencode(params)}"
        res_data = await asyncio.to_thread(self._sync_fetch, get_url)

        if res_data and (res_data.get("syncedLyrics") or res_data.get("plainLyrics")):
            synced = res_data.get("syncedLyrics")
            plain = res_data.get("plainLyrics")
            target_lrc = synced if synced else plain
            
            # Verify duration delta if duration was provided
            rec_dur = res_data.get("duration", 0)
            dur_delta = abs(rec_dur - duration) if (duration > 0 and rec_dur > 0) else 0.0
            confidence = 1.0 if dur_delta <= 2.0 else (0.8 if dur_delta <= 5.0 else 0.5)

            if dur_delta <= 6.0:
                return {
                    "raw_lrc": target_lrc,
                    "plain_text": plain,
                    "confidence": confidence,
                    "provider_name": self.name
                }

        # 2. Fallback Search via GET /api/search?q=title+artist
        search_query = f"{title} {artist}".strip()
        search_url = f"https://lrclib.net/api/search?q={urllib.parse.quote(search_query)}"
        search_results = await asyncio.to_thread(self._sync_fetch, search_url)

        if isinstance(search_results, list) and search_results:
            for item in search_results:
                synced = item.get("syncedLyrics")
                plain = item.get("plainLyrics")
                if not synced and not plain:
                    continue

                rec_dur = item.get("duration", 0)
                if duration > 0 and rec_dur > 0:
                    dur_delta = abs(rec_dur - duration)
                    if dur_delta > 5.0:
                        continue # Skip mismatched version/remix/live recording!

                return {
                    "raw_lrc": synced if synced else plain,
                    "plain_text": plain,
                    "confidence": 0.85,
                    "provider_name": self.name
                }

        return None
