import os
from pathlib import Path

class Settings:
    MUSIC_LIBRARY_PATH: str = os.getenv("MUSIC_LIBRARY_PATH", "/media/tharun/HD/Songs")
    BASE_DIR: Path = Path(__file__).resolve().parent.parent
    DB_PATH: str = os.getenv("DB_PATH", str(BASE_DIR / "music_server.db"))
    CACHE_DIR: Path = BASE_DIR / "cache" / "covers"
    HOST: str = os.getenv("HOST", "0.0.0.0")
    PORT: int = int(os.getenv("PORT", "8000"))

settings = Settings()
settings.CACHE_DIR.mkdir(parents=True, exist_ok=True)
