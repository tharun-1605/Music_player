import sys
import select
from pathlib import Path
import uvicorn

from app.config import settings

def prompt_music_directory_on_startup(timeout_seconds: int = 5):
    current_path = settings.MUSIC_LIBRARY_PATH
    print("\n==================================================")
    print(f" Current Music Folder Path: {current_path}")
    print(f" Press 'S' and Enter within {timeout_seconds} seconds to set a new music folder path.")
    print(f" Otherwise, automatically continuing in {timeout_seconds} seconds...")
    print("==================================================\n")

    if not sys.stdin.isatty():
        print("Non-interactive environment detected. Continuing with current path.\n")
        return

    try:
        rlist, _, _ = select.select([sys.stdin], [], [], timeout_seconds)
        if rlist:
            user_input = sys.stdin.readline().strip().lower()
            if user_input == 's':
                while True:
                    try:
                        new_path_str = input("Enter new music folder path: ").strip()
                        if not new_path_str:
                            print("No path entered. Keeping current path.\n")
                            break
                        p = Path(new_path_str).expanduser().resolve()
                        if not p.exists():
                            print(f"Error: Path '{p}' does not exist. Please try again.")
                            continue
                        if not p.is_dir():
                            print(f"Error: Path '{p}' is not a directory. Please try again.")
                            continue
                        settings.update_music_library_path(str(p))
                        print(f"Successfully updated music folder path to: {p}\n")
                        break
                    except (KeyboardInterrupt, EOFError):
                        print("\nCancelled path update. Using current path.\n")
                        break
            else:
                print("Continuing with current path...\n")
        else:
            print("Timeout reached. Continuing with current path...\n")
    except Exception as e:
        print(f"Continuing with current path (notice: {e})...\n")

if __name__ == "__main__":
    prompt_music_directory_on_startup(5)
    uvicorn.run(
        "app.main:app",
        host=settings.HOST,
        port=settings.PORT,
        reload=False
    )

