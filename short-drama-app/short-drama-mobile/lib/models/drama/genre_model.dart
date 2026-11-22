import 'package:flutter/material.dart';

import '../../core/media_url.dart';

/// A drama category / genre (Romance, CEO, Werewolf, …).
class GenreModel {
  final String id;
  final String slug;
  final String name;
  final String? description;
  final String? iconUrl;
  final String? colorHex;
  final int sortOrder;

  const GenreModel({
    required this.id,
    required this.slug,
    required this.name,
    this.description,
    this.iconUrl,
    this.colorHex,
    this.sortOrder = 0,
  });

  factory GenreModel.fromJson(Map<String, dynamic> json) {
    return GenreModel(
      id: json['id'] as String,
      slug: (json['slug'] ?? '') as String,
      name: (json['name'] ?? '') as String,
      description: json['description'] as String?,
      iconUrl: rewriteMediaUrl(json['iconUrl'] as String?),
      colorHex: json['colorHex'] as String?,
      sortOrder: (json['sortOrder'] as int?) ?? 0,
    );
  }

  /// Accent color parsed from `colorHex` (e.g. `#E63A6E`), or null.
  Color? get accentColor => _parseHexColor(colorHex);
}

/// Parse a `#RRGGBB` / `#AARRGGBB` string into a [Color].
Color? _parseHexColor(String? hex) {
  if (hex == null || hex.isEmpty) return null;
  var value = hex.replaceFirst('#', '').trim();
  if (value.length == 6) value = 'FF$value';
  final parsed = int.tryParse(value, radix: 16);
  return parsed == null ? null : Color(parsed);
}
