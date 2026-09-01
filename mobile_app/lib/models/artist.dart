class Artist {
  final int id;
  final String name;
  final int songCount;
  final int albumCount;

  Artist({
    required this.id,
    required this.name,
    required this.songCount,
    required this.albumCount,
  });

  factory Artist.fromJson(Map<String, dynamic> json) {
    return Artist(
      id: json['id'] as int,
      name: json['name'] as String? ?? 'Unknown Artist',
      songCount: json['song_count'] as int? ?? 0,
      albumCount: json['album_count'] as int? ?? 0,
    );
  }
}
