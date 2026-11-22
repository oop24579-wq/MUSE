import 'package:flutter/material.dart';

/// One parsed WebVTT cue.
class CaptionCue {
  final Duration start;
  final Duration end;
  final String text;

  const CaptionCue(
      {required this.start, required this.end, required this.text});

  bool contains(Duration position) =>
      position >= start && position < end;
}

/// Minimal pure-Dart WebVTT parser.
///
/// Tolerates `HH:MM:SS.mmm` and `MM:SS.mmm` timestamps, cue identifiers,
/// NOTE/STYLE blocks and multi-line cue text (tags stripped).
List<CaptionCue> parseWebVtt(String source) {
  final cues = <CaptionCue>[];
  final lines =
      source.replaceAll('\r\n', '\n').replaceAll('\r', '\n').split('\n');
  var i = 0;
  while (i < lines.length) {
    final line = lines[i].trim();
    if (!line.contains('-->')) {
      i++;
      continue;
    }
    final parts = line.split('-->');
    if (parts.length < 2) {
      i++;
      continue;
    }
    final start = _parseTimestamp(parts[0].trim());
    final endToken = parts[1].trim().split(RegExp(r'\s+')).first;
    final end = _parseTimestamp(endToken);
    i++;
    final textLines = <String>[];
    while (i < lines.length && lines[i].trim().isNotEmpty) {
      textLines.add(lines[i].trim());
      i++;
    }
    if (start != null && end != null && textLines.isNotEmpty) {
      final text = textLines
          .join('\n')
          .replaceAll(RegExp(r'<[^>]*>'), '')
          .trim();
      if (text.isNotEmpty) {
        cues.add(CaptionCue(start: start, end: end, text: text));
      }
    }
  }
  return cues;
}

Duration? _parseTimestamp(String raw) {
  final match = RegExp(
          r'^(?:(\d+):)?(\d{1,2}):(\d{2})(?:[.,](\d{1,3}))?$')
      .firstMatch(raw.trim());
  if (match == null) return null;
  final hours = int.tryParse(match.group(1) ?? '0') ?? 0;
  final minutes = int.tryParse(match.group(2) ?? '0') ?? 0;
  final seconds = int.tryParse(match.group(3) ?? '0') ?? 0;
  var ms = int.tryParse(match.group(4) ?? '0') ?? 0;
  final frac = match.group(4);
  if (frac != null && frac.length == 1) ms *= 100;
  if (frac != null && frac.length == 2) ms *= 10;
  return Duration(
      hours: hours, minutes: minutes, seconds: seconds, milliseconds: ms);
}

/// Returns the cue text active at [position], or null.
String? activeCaptionText(List<CaptionCue> cues, Duration position) {
  for (final cue in cues) {
    if (cue.contains(position)) return cue.text;
  }
  return null;
}

/// Bottom overlay pill rendering the active caption cue.
class CaptionOverlay extends StatelessWidget {
  const CaptionOverlay({
    super.key,
    required this.text,
    required this.fontSize,
  });

  final String text;
  final double fontSize;

  @override
  Widget build(BuildContext context) {
    return IgnorePointer(
      child: Align(
        alignment: Alignment.bottomCenter,
        child: Padding(
          padding: const EdgeInsets.only(bottom: 96, left: 24, right: 24),
          child: Container(
            padding:
                const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
            decoration: BoxDecoration(
              color: Colors.black.withValues(alpha: 0.65),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Text(
              text,
              textAlign: TextAlign.center,
              style: TextStyle(
                color: Colors.white,
                fontSize: fontSize,
                height: 1.3,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
        ),
      ),
    );
  }
}
