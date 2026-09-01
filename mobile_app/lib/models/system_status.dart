class SystemStatus {
  final bool hddConnected;
  final String musicPath;
  final bool readable;
  final int totalFiles;
  final String dbStatus;
  final int totalSongsInDb;
  final int totalArtistsInDb;
  final int totalAlbumsInDb;

  SystemStatus({
    required this.hddConnected,
    required this.musicPath,
    required this.readable,
    required this.totalFiles,
    required this.dbStatus,
    required this.totalSongsInDb,
    required this.totalArtistsInDb,
    required this.totalAlbumsInDb,
  });

  factory SystemStatus.fromJson(Map<String, dynamic> json) {
    return SystemStatus(
      hddConnected: json['hdd_connected'] as bool? ?? false,
      musicPath: json['music_path'] as String? ?? '',
      readable: json['readable'] as bool? ?? false,
      totalFiles: json['total_files'] as int? ?? 0,
      dbStatus: json['db_status'] as String? ?? 'unknown',
      totalSongsInDb: json['total_songs_in_db'] as int? ?? 0,
      totalArtistsInDb: json['total_artists_in_db'] as int? ?? 0,
      totalAlbumsInDb: json['total_albums_in_db'] as int? ?? 0,
    );
  }
}
