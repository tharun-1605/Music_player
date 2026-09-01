import 'song.dart';

class Playlist {
  final int id;
  final String name;
  final int songCount;
  final String createdAt;
  final List<Song>? songs;

  Playlist({
    required this.id,
    required this.name,
    required this.songCount,
    required this.createdAt,
    this.songs,
  });

  factory Playlist.fromJson(Map<String, dynamic> json) {
    return Playlist(
      id: json['id'] as int,
      name: json['name'] as String? ?? 'Untitled Playlist',
      songCount: json['song_count'] as int? ?? 0,
      createdAt: json['created_at'] as String? ?? '',
      songs: json['songs'] != null
          ? (json['songs'] as List).map((s) => Song.fromJson(s as Map<String, dynamic>)).toList()
          : null,
    );
  }
}
