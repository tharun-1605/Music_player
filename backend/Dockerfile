FROM python:3.11-slim

WORKDIR /app

# Install system dependencies if required (e.g. for mutagen/pillow)
RUN apt-get update && apt-get install -y --no-install-recommends \
    curl \
    && rm -rf /var/lib/apt/lists/*

# Copy requirements and install dependencies
COPY requirements.txt .
RUN pip install --no-cache-dir -r requirements.txt

# Copy application files
COPY app ./app
COPY run.py .

# Create directories for mounted volume and data/cache
RUN mkdir -p /music /app/data /app/cache/covers

# Set environment variables
ENV MUSIC_LIBRARY_PATH=/music \
    DB_PATH=/app/data/music_server.db \
    HOST=0.0.0.0 \
    PORT=8000 \
    PYTHONUNBUFFERED=1

EXPOSE 8000

# Health check
HEALTHCHECK --interval=30s --timeout=5s --start-period=5s --retries=3 \
  CMD curl -f http://localhost:8000/api/health || exit 1

CMD ["python", "run.py"]
