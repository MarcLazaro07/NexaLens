import 'dart:convert';

class SavedWord {
  final String id;
  final String original;
  final String translated;
  final String srcLang;
  final String tgtLang;
  final String category; // 'AR', 'Conversation', 'Photo', 'Manual'
  final DateTime createdAt;

  SavedWord({
    required this.id,
    required this.original,
    required this.translated,
    required this.srcLang,
    required this.tgtLang,
    required this.category,
    required this.createdAt,
  });

  Map<String, dynamic> toJson() => {
    'id': id,
    'original': original,
    'translated': translated,
    'srcLang': srcLang,
    'tgtLang': tgtLang,
    'category': category,
    'createdAt': createdAt.toIso8601String(),
  };

  factory SavedWord.fromJson(Map<String, dynamic> json) => SavedWord(
    id: json['id'] as String,
    original: json['original'] as String,
    translated: json['translated'] as String,
    srcLang: json['srcLang'] as String,
    tgtLang: json['tgtLang'] as String,
    category: json['category'] as String,
    createdAt: DateTime.parse(json['createdAt'] as String),
  );

  static String encode(List<SavedWord> words) =>
      json.encode(words.map((w) => w.toJson()).toList());

  static List<SavedWord> decode(String data) =>
      (json.decode(data) as List).map((e) => SavedWord.fromJson(e)).toList();
}
