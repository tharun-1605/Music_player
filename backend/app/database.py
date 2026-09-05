from sqlalchemy import create_engine, event
from sqlalchemy.orm import sessionmaker, declarative_base
from app.config import settings

sqlite_url = f"sqlite:///{settings.DB_PATH}"

engine = create_engine(
    sqlite_url,
    connect_args={"check_same_thread": False}
)

@event.listens_for(engine, "connect")
def set_sqlite_pragma(dbapi_connection, connection_record):
    cursor = dbapi_connection.cursor()
    cursor.execute("PRAGMA journal_mode=WAL")
    cursor.execute("PRAGMA foreign_keys=ON")
    cursor.close()

SessionLocal = sessionmaker(autocommit=False, autoflush=False, bind=engine)
Base = declarative_base()

def get_db():
    db = SessionLocal()
    try:
        yield db
    finally:
        db.close()

def init_db_schema():
    from sqlalchemy import text
    Base.metadata.create_all(bind=engine)
    with engine.connect() as conn:
        cols = [row[1] for row in conn.execute(text("PRAGMA table_info(playlists)")).fetchall()]
        if "is_system" not in cols:
            conn.execute(text("ALTER TABLE playlists ADD COLUMN is_system INTEGER DEFAULT 0"))
            conn.commit()

        tables = [row[0] for row in conn.execute(text("SELECT name FROM sqlite_master WHERE type='table'")).fetchall()]
        if "lyrics" in tables:
            l_cols = [row[1] for row in conn.execute(text("PRAGMA table_info(lyrics)")).fetchall()]
            if "provider" not in l_cols:
                conn.execute(text("ALTER TABLE lyrics ADD COLUMN provider TEXT"))
            if "match_confidence" not in l_cols:
                conn.execute(text("ALTER TABLE lyrics ADD COLUMN match_confidence FLOAT DEFAULT 1.0"))
            if "fetch_timestamp" not in l_cols:
                conn.execute(text("ALTER TABLE lyrics ADD COLUMN fetch_timestamp DATETIME"))
            conn.commit()

