class LyricLine {
  final double time; // in seconds
  final String text;

  LyricLine({
    required this.time,
    required this.text,
  });

  factory LyricLine.fromJson(Map<String, dynamic> json) {
    return LyricLine(
      time: (json['time'] as num?)?.toDouble() ?? 0.0,
      text: json['text'] as String? ?? '',
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'time': time,
      'text': text,
    };
  }

  Duration get duration => Duration(milliseconds: (time * 1000).round());
}

class SongLyrics {
  final int songId;
  final String lyricsSource; // 'db', 'lrc', 'embedded', 'manual', 'unavailable'
  final String? plainLyrics;
  final List<LyricLine> timedLyrics;
  final bool isSynced;
  final int offset; // in milliseconds
  final bool isManual;

  SongLyrics({
    required this.songId,
    required this.lyricsSource,
    this.plainLyrics,
    this.timedLyrics = const [],
    this.isSynced = false,
    this.offset = 0,
    this.isManual = false,
  });

  factory SongLyrics.fromJson(Map<String, dynamic> json) {
    final rawTimed = json['timed_lyrics'] as List<dynamic>? ?? [];
    final timedList = rawTimed.map((item) => LyricLine.fromJson(item as Map<String, dynamic>)).toList();

    return SongLyrics(
      songId: json['song_id'] as int? ?? 0,
      lyricsSource: json['lyrics_source'] as String? ?? 'unavailable',
      plainLyrics: json['plain_lyrics'] as String?,
      timedLyrics: timedList,
      isSynced: json['is_synced'] as bool? ?? (timedList.isNotEmpty),
      offset: json['offset'] as int? ?? 0,
      isManual: json['is_manual'] as bool? ?? false,
    );
  }

  static SongLyrics parseLrcString(int songId, String rawLrc, {int offset = 0}) {
    if (rawLrc.trim().isEmpty) {
      return SongLyrics(songId: songId, lyricsSource: 'manual', isSynced: false);
    }

    final lines = rawLrc.split('\n');
    final timedList = <LyricLine>[];
    final plainList = <String>[];
    int parsedOffset = offset;

    // Regexp for timestamp: [mm:ss.xx] or [mm:ss.xxx]
    final tsRegex = RegExp(r'\[(\d{1,3}):(\d{2})(?:[.:](\d{1,3}))?\]');
    final metaRegex = RegExp(r'^\[(ti|ar|al|au|by|offset|re|ve|length):', caseSensitive: false);
    final offsetRegex = RegExp(r'\[offset:\s*([+-]?\d+)\]', caseSensitive: false);

    final offsetMatch = offsetRegex.firstMatch(rawLrc);
    if (offsetMatch != null) {
      parsedOffset += int.tryParse(offsetMatch.group(1) ?? '0') ?? 0;
    }

    for (final line in lines) {
      final lineStr = line.trim();
      if (lineStr.isEmpty) continue;

      if (metaRegex.hasMatch(lineStr)) {
        continue;
      }

      final matches = tsRegex.allMatches(lineStr).toList();
      if (matches.isNotEmpty) {
        final textContent = lineStr.replaceAll(tsRegex, '').trim();
        for (final m in matches) {
          final mins = int.parse(m.group(1)!);
          final secs = int.parse(m.group(2)!);
          final fracStr = m.group(3);
          double frac = 0.0;
          if (fracStr != null && fracStr.isNotEmpty) {
            frac = int.parse(fracStr) / double.parse('1${'0' * fracStr.length}');
          }

          double totalSec = mins * 60 + secs + frac;
          totalSec += parsedOffset / 1000.0;
          if (totalSec < 0) totalSec = 0.0;

          timedList.add(LyricLine(time: double.parse(totalSec.toStringAsFixed(3)), text: textContent));
        }
      } else {
        plainList.add(lineStr);
      }
    }

    if (timedList.isNotEmpty) {
      timedList.sort((a, b) => a.time.compareTo(b.time));
      return SongLyrics(
        songId: songId,
        lyricsSource: 'manual',
        plainLyrics: rawLrc,
        timedLyrics: timedList,
        isSynced: true,
        offset: parsedOffset,
        isManual: true,
      );
    } else {
      return SongLyrics(
        songId: songId,
        lyricsSource: 'manual',
        plainLyrics: plainList.join('\n'),
        timedLyrics: [],
        isSynced: false,
        offset: parsedOffset,
        isManual: true,
      );
    }
  }
}
