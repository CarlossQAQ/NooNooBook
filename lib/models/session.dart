class SubtitleItemData {
  final String sourceText;
  final String translatedText;
  final String timestamp;

  SubtitleItemData({
    required this.sourceText,
    required this.translatedText,
    required this.timestamp,
  });

  Map<String, dynamic> toJson() => {
    'sourceText': sourceText,
    'translatedText': translatedText,
    'timestamp': timestamp,
  };

  factory SubtitleItemData.fromJson(Map<String, dynamic> json) => SubtitleItemData(
    sourceText: json['sourceText'] ?? '',
    translatedText: json['translatedText'] ?? '',
    timestamp: json['timestamp'] ?? '',
  );
}

class Session {
  final String id;
  String title;
  final DateTime startTime;
  DateTime? endTime;
  final String direction;
  final List<SubtitleItemData> items;
  Map<String, dynamic>? summary;

  Session({
    required this.id,
    required this.title,
    required this.startTime,
    this.endTime,
    required this.direction,
    List<SubtitleItemData>? items,
    this.summary,
  }) : items = items ?? [];

  Duration get duration {
    if (endTime == null) return Duration.zero;
    return endTime!.difference(startTime);
  }

  String get durationText {
    final d = duration;
    if (d.inHours > 0) return '${d.inHours}h ${d.inMinutes.remainder(60)}m';
    if (d.inMinutes > 0) return '${d.inMinutes}m ${d.inSeconds.remainder(60)}s';
    return '${d.inSeconds}s';
  }

  Map<String, dynamic> toJson() => {
    'id': id,
    'title': title,
    'startTime': startTime.toIso8601String(),
    'endTime': endTime?.toIso8601String(),
    'direction': direction,
    'items': items.map((i) => i.toJson()).toList(),
    'summary': summary,
  };

  factory Session.fromJson(Map<String, dynamic> json) => Session(
    id: json['id'] ?? '',
    title: json['title'] ?? '',
    startTime: DateTime.parse(json['startTime']),
    endTime: json['endTime'] != null ? DateTime.parse(json['endTime']) : null,
    direction: json['direction'] ?? 'EN_ZH',
    items: (json['items'] as List?)?.map((i) => SubtitleItemData.fromJson(i)).toList() ?? [],
    summary: json['summary'] as Map<String, dynamic>?,
  );
}
