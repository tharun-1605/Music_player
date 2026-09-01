import os
from pathlib import Path
from typing import Generator
from fastapi import HTTPException, Request, status
from fastapi.responses import StreamingResponse

MIME_TYPES = {
    ".flac": "audio/flac",
    ".m4a": "audio/mp4",
    ".mp4": "audio/mp4",
    ".opus": "audio/ogg",
    ".ogg": "audio/ogg",
    ".wav": "audio/wav",
    ".mp3": "audio/mpeg",
    ".aac": "audio/aac"
}

CHUNK_SIZE = 256 * 1024  # 256 KB chunks

def validate_safe_path(file_path: str, base_dir: str) -> Path:
    """Ensure path exists, is a file, and strictly within base_dir (prevents traversal)."""
    target = Path(file_path).resolve()
    allowed_base = Path(base_dir).resolve()
    
    try:
        target.relative_to(allowed_base)
    except ValueError:
        raise HTTPException(
            status_code=status.HTTP_403_FORBIDDEN,
            detail="Access denied: File path outside configured music library."
        )

    if not target.exists() or not target.is_file():
        raise HTTPException(
            status_code=status.HTTP_404_NOT_FOUND,
            detail="Audio file not found on storage."
        )

    return target

def get_media_type(path: Path) -> str:
    ext = path.suffix.lower()
    return MIME_TYPES.get(ext, "application/octet-stream")

def file_iterator(file_path: Path, start: int, length: int, chunk_size: int = CHUNK_SIZE) -> Generator[bytes, None, None]:
    with open(file_path, "rb") as f:
        f.seek(start)
        remaining = length
        while remaining > 0:
            bytes_to_read = min(remaining, chunk_size)
            data = f.read(bytes_to_read)
            if not data:
                break
            remaining -= len(data)
            yield data

def stream_audio_file(request: Request, file_path_str: str, base_dir: str) -> StreamingResponse:
    path = validate_safe_path(file_path_str, base_dir)
    file_size = path.stat().st_size
    media_type = get_media_type(path)

    range_header = request.headers.get("range")

    headers = {
        "Accept-Ranges": "bytes",
        "Content-Type": media_type,
    }

    if range_header:
        try:
            unit, range_val = range_header.strip().split("=")
            if unit.strip().lower() != "bytes":
                raise ValueError
            
            parts = range_val.split("-")
            start_str = parts[0].strip()
            end_str = parts[1].strip() if len(parts) > 1 else ""

            if start_str and end_str:
                start = int(start_str)
                end = int(end_str)
            elif start_str:
                start = int(start_str)
                end = file_size - 1
            elif end_str:
                end = file_size - 1
                start = max(0, file_size - int(end_str))
            else:
                start = 0
                end = file_size - 1

            if start >= file_size or end >= file_size or start > end:
                raise HTTPException(
                    status_code=status.HTTP_416_REQUESTED_RANGE_NOT_SATISFIABLE,
                    headers={"Content-Range": f"bytes */{file_size}"}
                )

            content_length = end - start + 1
            headers["Content-Range"] = f"bytes {start}-{end}/{file_size}"
            headers["Content-Length"] = str(content_length)

            return StreamingResponse(
                file_iterator(path, start, content_length),
                status_code=status.HTTP_206_PARTIAL_CONTENT,
                headers=headers,
                media_type=media_type
            )
        except (ValueError, IndexError):
            pass

    headers["Content-Length"] = str(file_size)
    return StreamingResponse(
        file_iterator(path, 0, file_size),
        status_code=status.HTTP_200_OK,
        headers=headers,
        media_type=media_type
    )
