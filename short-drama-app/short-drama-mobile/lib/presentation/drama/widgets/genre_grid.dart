import 'package:flutter/material.dart';
import 'package:sizer/sizer.dart';

import '../../../core/app_export.dart';
import '../../../models/drama/genre_model.dart';

/// A colored genre pill.
class GenreChip extends StatelessWidget {
  const GenreChip({super.key, required this.genre, this.onTap, this.selected = false});

  final GenreModel genre;
  final VoidCallback? onTap;
  final bool selected;

  @override
  Widget build(BuildContext context) {
    final accent = genre.accentColor ?? AppTheme.accentBlue;
    return GestureDetector(
      onTap: onTap,
      behavior: HitTestBehavior.opaque,
      child: Container(
        padding: EdgeInsets.symmetric(horizontal: 4.w, vertical: 1.2.h),
        decoration: BoxDecoration(
          gradient: LinearGradient(
            colors: [accent.withValues(alpha: 0.85), accent.withValues(alpha: 0.55)],
          ),
          borderRadius: BorderRadius.circular(12),
          border: selected
              ? Border.all(color: Colors.white.withValues(alpha: 0.9), width: 1.5)
              : null,
        ),
        child: Text(
          genre.name,
          style: TextStyle(
            color: Colors.white,
            fontSize: 10.sp,
            fontWeight: FontWeight.w700,
          ),
        ),
      ),
    );
  }
}

/// A wrap grid of genre chips (used inline on the home feed).
class GenreGrid extends StatelessWidget {
  const GenreGrid({super.key, required this.genres, required this.onSelected});

  final List<GenreModel> genres;
  final void Function(GenreModel genre) onSelected;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.symmetric(horizontal: 4.w),
      child: Wrap(
        spacing: 2.5.w,
        runSpacing: 1.2.h,
        children: [
          for (final g in genres)
            GenreChip(genre: g, onTap: () => onSelected(g)),
        ],
      ),
    );
  }
}

IconData genreIcon(String slug) {
  switch (slug) {
    case 'romance':
      return Icons.favorite_rounded;
    case 'ceo':
      return Icons.business_center_rounded;
    case 'revenge':
      return Icons.bolt_rounded;
    case 'werewolf':
      return Icons.dark_mode_rounded;
    case 'rebirth':
      return Icons.autorenew_rounded;
    case 'marriage':
      return Icons.diamond_rounded;
    case 'secret':
      return Icons.visibility_off_rounded;
    case 'mafia':
      return Icons.local_police_rounded;
    case 'historical':
      return Icons.castle_rounded;
    case 'campus':
      return Icons.school_rounded;
    case 'thriller':
      return Icons.warning_amber_rounded;
    case 'fantasy':
      return Icons.auto_awesome_rounded;
    default:
      return Icons.movie_rounded;
  }
}

/// A large gradient category card for the Categories grid.
class GenreCard extends StatelessWidget {
  const GenreCard({super.key, required this.genre, this.onTap});

  final GenreModel genre;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final accent = genre.accentColor ?? AppTheme.accentBlue;
    return GestureDetector(
      onTap: onTap,
      behavior: HitTestBehavior.opaque,
      child: ClipRRect(
        borderRadius: BorderRadius.circular(14),
        child: Container(
          decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: [
                Color.lerp(accent, Colors.black, 0.05)!,
                Color.lerp(accent, Colors.black, 0.35)!,
              ],
            ),
          ),
          child: Padding(
            padding: EdgeInsets.all(3.5.w),
            child: Align(
              alignment: Alignment.centerLeft,
              child: Text(
                genre.name,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 12.sp,
                  fontWeight: FontWeight.w800,
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// A 2-column grid of category cards (Discover → Categories).
class GenreCardGrid extends StatelessWidget {
  const GenreCardGrid({super.key, required this.genres, required this.onSelected});

  final List<GenreModel> genres;
  final void Function(GenreModel genre) onSelected;

  @override
  Widget build(BuildContext context) {
    return GridView.builder(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      padding: EdgeInsets.symmetric(horizontal: 4.w),
      gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 2,
        mainAxisSpacing: 3.w,
        crossAxisSpacing: 3.w,
        childAspectRatio: 1.7,
      ),
      itemCount: genres.length,
      itemBuilder: (_, i) =>
          GenreCard(genre: genres[i], onTap: () => onSelected(genres[i])),
    );
  }
}
