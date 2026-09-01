class Song {
  final int id;
  final String title;
  final String artist;
  final String album;
  final String? albumArtist;
  final String? genre;
  final int? year;
  final int? trackNumber;
  final int? discNumber;
  final double duration;
  final int bitrate;
  final int sampleRate;
  final String codec;
  final int fileSize;
  final String filePath;
  final String? coverArtPath;
  final bool isFavorite;

  Song({
    required this.id,
    required this.title,
    required this.artist,
    required this.album,
    this.albumArtist,
    this.genre,
    this.year,
    this.trackNumber,
    this.discNumber,
    required this.duration,
    required this.bitrate,
    required this.sampleRate,
    required this.codec,
    required this.fileSize,
    required this.filePath,
    this.coverArtPath,
    this.isFavorite = false,
  });

  factory Song.fromJson(Map<String, dynamic> json) {
    return Song(
      id: json['id'] as int,
      title: json['title'] as String? ?? 'Unknown Title',
      artist: json['artist'] as String? ?? 'Unknown Artist',
      album: json['album'] as String? ?? 'Unknown Album',
      albumArtist: json['album_artist'] as String?,
      genre: json['genre'] as String?,
      year: json['year'] as int?,
      trackNumber: json['track_number'] as int?,
      discNumber: json['disc_number'] as int?,
      duration: (json['duration'] as num?)?.toDouble() ?? 0.0,
      bitrate: json['bitrate'] as int? ?? 0,
      sampleRate: json['sample_rate'] as int? ?? 0,
      codec: json['codec'] as String? ?? '',
      fileSize: json['file_size'] as int? ?? 0,
      filePath: json['file_path'] as String? ?? '',
      coverArtPath: json['cover_art_path'] as String?,
      isFavorite: json['is_favorite'] as bool? ?? false,
    );
  }

  Song copyWith({bool? isFavorite}) {
    return Song(
      id: id,
      title: title,
      artist: artist,
      album: album,
      albumArtist: albumArtist,
      genre: genre,
      year: year,
      trackNumber: trackNumber,
      discNumber: discNumber,
      duration: duration,
      bitrate: bitrate,
      sampleRate: sampleRate,
      codec: codec,
      fileSize: fileSize,
      filePath: filePath,
      coverArtPath: coverArtPath,
      isFavorite: isFavorite ?? this.isFavorite,
    );
  }
}
