import '../../core/media_url.dart';

/// A cast credit on a series (character + person).
class CastMember {
  final String id;
  final String? characterName;
  final int sortOrder;
  final String personId;
  final String personSlug;
  final String personName;
  final String? personGender;
  final String? personImageUrl;

  const CastMember({
    required this.id,
    this.characterName,
    this.sortOrder = 0,
    required this.personId,
    required this.personSlug,
    required this.personName,
    this.personGender,
    this.personImageUrl,
  });

  /// Accepts nested `person: { id, slug, name, gender, imageUrl }` or flat fields.
  factory CastMember.fromJson(Map<String, dynamic> json) {
    final personRaw = json['person'];
    final person =
        personRaw is Map ? Map<String, dynamic>.from(personRaw) : null;

    return CastMember(
      id: (json['id'] ?? '') as String,
      characterName: json['characterName'] as String?,
      sortOrder: (json['sortOrder'] as num?)?.toInt() ?? 0,
      personId: (person?['id'] ?? json['personId'] ?? '') as String,
      personSlug: (person?['slug'] ?? json['personSlug'] ?? '') as String,
      personName: (person?['name'] ?? json['personName'] ?? '') as String,
      personGender: (person?['gender'] ?? json['personGender']) as String?,
      personImageUrl: rewriteMediaUrl(
        (person?['imageUrl'] ?? json['personImageUrl']) as String?,
      ),
    );
  }
}
