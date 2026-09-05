from abc import ABC, abstractmethod
from typing import Optional, Dict, Any

class BaseLyricsProvider(ABC):
    @property
    @abstractmethod
    def name(self) -> str:
        """Name of the lyrics provider."""
        pass

    @abstractmethod
    async def search_lyrics(
        self,
        title: str,
        artist: str,
        album: str,
        duration: float,
    ) -> Optional[Dict[str, Any]]:
        """
        Search for lyrics matching track metadata.
        Returns dict with:
        {
          "raw_lrc": str,
          "plain_text": str,
          "confidence": float, # 0.0 to 1.0
          "provider_name": str
        }
        or None if not found or low confidence.
        """
        pass
