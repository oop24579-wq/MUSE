/// Content kinds referenced by home shelves, favorites and search.
enum DramaContentType {
  series('series'),
  episode('episode'),
  genre('genre');

  const DramaContentType(this.value);
  final String value;

  static DramaContentType? fromString(String? v) {
    if (v == null) return null;
    for (final t in DramaContentType.values) {
      if (t.value == v) return t;
    }
    return null;
  }
}

/// Home section layout kinds (server-driven via HomeSection.sectionType).
enum SectionType {
  featuredHero('featured_hero'),
  seriesCarousel('series_carousel'),
  rankingList('ranking_list'),
  newReleases('new_releases'),
  genreGrid('genre_grid'),
  verticalGrid('vertical_grid'),
  hotGrid('hot_grid'),
  continueWatching('continue_watching'),
  forYou('for_you'),
  unknown('unknown');

  const SectionType(this.value);
  final String value;

  static SectionType fromString(String? v) {
    if (v == null) return SectionType.unknown;
    for (final t in SectionType.values) {
      if (t.value == v) return t;
    }
    return SectionType.unknown;
  }
}

/// Top filter tabs on the Discover page.
enum DiscoverFilter { popular, latest, ranking, categories }

/// Segment tabs on the My List page.
enum MyListTab { recentlyWatched, collection }
