import 'content_type.dart';
import 'series_model.dart';

/// A home-feed shelf. Metadata comes from `HomeSection`; `items` (series) are
/// hydrated by the data service from `HomeSectionItem` + `Series`.
class HomeSectionModel {
  final String id;
  final String slug;
  final String title;
  final String? subtitle;
  final SectionType sectionType;
  final int sortOrder;
  final List<SeriesModel> items;

  const HomeSectionModel({
    required this.id,
    required this.slug,
    required this.title,
    this.subtitle,
    required this.sectionType,
    this.sortOrder = 0,
    this.items = const [],
  });

  factory HomeSectionModel.fromJson(
    Map<String, dynamic> json, {
    List<SeriesModel> items = const [],
  }) {
    return HomeSectionModel(
      id: json['id'] as String,
      slug: (json['slug'] ?? '') as String,
      title: (json['title'] ?? '') as String,
      subtitle: json['subtitle'] as String?,
      sectionType: SectionType.fromString(json['sectionType'] as String?),
      sortOrder: (json['sortOrder'] as int?) ?? 0,
      items: items,
    );
  }

  HomeSectionModel withItems(List<SeriesModel> newItems) => HomeSectionModel(
        id: id,
        slug: slug,
        title: title,
        subtitle: subtitle,
        sectionType: sectionType,
        sortOrder: sortOrder,
        items: newItems,
      );

  bool get isEmpty =>
      items.isEmpty && sectionType != SectionType.genreGrid;
}
