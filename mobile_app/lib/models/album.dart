class Album {
  final int id;
  final String title;
  final String artist;
  final int? year;
  final String? coverArtPath;
  final int songCount;

  Album({
    required this.id,
    required this.title,
    required this.artist,
    this.year,
    this.coverArtPath,
    required this.songCount,
  });

  factory Album.fromJson(Map<String, dynamic> json) {
    return Album(
      id: json['id'] as int,
      title: json['title'] as String? ?? 'Unknown Album',
      artist: json['artist'] as String? ?? 'Unknown Artist',
      year: json['year'] as int?,
      coverArtPath: json['cover_art_path'] as String?,
      songCount: json['song_count'] as int? ?? 0,
    );
  }
}
