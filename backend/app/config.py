import os
import json
from pathlib import Path

BASE_DIR: Path = Path(__file__).resolve().parent.parent
CONFIG_FILE: Path = BASE_DIR / "config.json"

def load_persisted_config() -> dict:
    if CONFIG_FILE.exists():
        try:
            with open(CONFIG_FILE, "r") as f:
                return json.load(f)
        except Exception:
            pass
    return {}

_persisted_config = load_persisted_config()

def resolve_initial_music_path() -> str:
    candidates = []
    env_path = os.getenv("MUSIC_LIBRARY_PATH")
    if env_path:
        candidates.append(env_path)

    cfg_path = _persisted_config.get("MUSIC_LIBRARY_PATH")
    if cfg_path:
        candidates.append(cfg_path)

    candidates.extend([
        "/media/ninja/SSD/Music-FLAC",
        "/media/tharun/HD/Songs",
        str(Path.home() / "Music")
    ])

    for c in candidates:
        if c and Path(c).exists() and Path(c).is_dir():
            return str(Path(c).resolve())

    return cfg_path or env_path or "/media/tharun/HD/Songs"

class Settings:
    BASE_DIR: Path = BASE_DIR
    MUSIC_LIBRARY_PATH: str = resolve_initial_music_path()
    DB_PATH: str = os.getenv("DB_PATH", str(BASE_DIR / "music_server.db"))
    CACHE_DIR: Path = BASE_DIR / "cache" / "covers"
    HOST: str = os.getenv("HOST", "0.0.0.0")
    PORT: int = int(os.getenv("PORT", "8000"))

    def update_music_library_path(self, new_path: str, persist: bool = True) -> bool:
        self.MUSIC_LIBRARY_PATH = new_path
        if not persist:
            return True
        try:
            data = {}
            if CONFIG_FILE.exists():
                try:
                    with open(CONFIG_FILE, "r") as f:
                        data = json.load(f)
                except Exception:
                    data = {}
            data["MUSIC_LIBRARY_PATH"] = new_path
            with open(CONFIG_FILE, "w") as f:
                json.dump(data, f, indent=2)
            return True
        except Exception:
            return False

settings = Settings()
settings.CACHE_DIR.mkdir(parents=True, exist_ok=True)


