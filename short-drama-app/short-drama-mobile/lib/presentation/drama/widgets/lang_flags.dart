import 'package:flutter/material.dart';
import 'package:sizer/sizer.dart';

/// Language code → flag emoji (dubbing tracks shown on a cover).
const Map<String, String> kLangFlags = {
  'en': '🇬🇧',
  'us': '🇺🇸',
  'tr': '🇹🇷',
  'es': '🇪🇸',
  'pt': '🇧🇷',
  'de': '🇩🇪',
  'fr': '🇫🇷',
  'it': '🇮🇹',
  'ja': '🇯🇵',
  'ko': '🇰🇷',
  'ar': '🇸🇦',
  'zh': '🇨🇳',
  'ru': '🇷🇺',
  'id': '🇮🇩',
  'hi': '🇮🇳',
};

const Map<String, String> kLangNames = {
  'en': 'English',
  'tr': 'Türkçe',
  'es': 'Español',
  'pt': 'Português',
  'de': 'Deutsch',
  'fr': 'Français',
  'it': 'Italiano',
  'ja': '日本語',
  'ko': '한국어',
  'ar': 'العربية',
  'zh': '中文',
  'ru': 'Русский',
  'id': 'Indonesia',
  'hi': 'हिन्दी',
};

String flagFor(String code) => kLangFlags[code.toLowerCase()] ?? '🏳️';
String langName(String code) => kLangNames[code.toLowerCase()] ?? code.toUpperCase();

/// A compact translucent chip of dubbing language flags (max [max], then +N).
class LangFlags extends StatelessWidget {
  const LangFlags({
    super.key,
    required this.codes,
    this.max = 3,
    this.fontSize = 12,
  });

  final List<String> codes;
  final int max;
  final double fontSize;

  @override
  Widget build(BuildContext context) {
    if (codes.isEmpty) return const SizedBox.shrink();
    final shown = codes.take(max).toList();
    final extra = codes.length - shown.length;

    return Container(
      padding: EdgeInsets.symmetric(horizontal: 1.3.w, vertical: 0.25.h),
      decoration: BoxDecoration(
        color: Colors.black.withValues(alpha: 0.5),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          for (var i = 0; i < shown.length; i++)
            Padding(
              padding: EdgeInsets.only(right: i == shown.length - 1 && extra == 0 ? 0 : 0.6.w),
              child: Text(flagFor(shown[i]), style: TextStyle(fontSize: fontSize)),
            ),
          if (extra > 0)
            Text(
              '+$extra',
              style: TextStyle(
                color: Colors.white,
                fontSize: fontSize * 0.72,
                fontWeight: FontWeight.w700,
              ),
            ),
        ],
      ),
    );
  }
}
