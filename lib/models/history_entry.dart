import 'dart:convert';

class HistoryEntry {
  final String id;
  final String type; // 'AR', 'Conversation', 'Photo'
  final String originalText;
  final String translatedText;
  final String srcLang;
  final String tgtLang;
  final DateTime createdAt;

  HistoryEntry({
    required this.id,
    required this.type,
    required this.originalText,
    required this.translatedText,
    required this.srcLang,
    required this.tgtLang,
    required this.createdAt,
  });

  Map<String, dynamic> toJson() => {
    'id': id,
    'type': type,
    'originalText': originalText,
    'translatedText': translatedText,
    'srcLang': srcLang,
    'tgtLang': tgtLang,
    'createdAt': createdAt.toIso8601String(),
  };

  factory HistoryEntry.fromJson(Map<String, dynamic> json) => HistoryEntry(
    id: json['id'] as String,
    type: json['type'] as String,
    originalText: json['originalText'] as String,
    translatedText: json['translatedText'] as String,
    srcLang: json['srcLang'] as String,
    tgtLang: json['tgtLang'] as String,
    createdAt: DateTime.parse(json['createdAt'] as String),
  );

  static String encode(List<HistoryEntry> entries) =>
      json.encode(entries.map((e) => e.toJson()).toList());

  static List<HistoryEntry> decode(String data) =>
      (json.decode(data) as List).map((e) => HistoryEntry.fromJson(e)).toList();
}
