import 'package:flutter_test/flutter_test.dart';

import 'package:drama_now/presentation/drama/widgets/player/caption_overlay.dart';

void main() {
  group('parseWebVtt', () {
    test('parses HH:MM:SS.mmm cues', () {
      const vtt = '''
WEBVTT

00:00:01.000 --> 00:00:04.500
Hello world

00:00:05.000 --> 00:00:08.250
Second line
''';
      final cues = parseWebVtt(vtt);
      expect(cues, hasLength(2));
      expect(cues[0].start, const Duration(seconds: 1));
      expect(cues[0].end, const Duration(milliseconds: 4500));
      expect(cues[0].text, 'Hello world');
      expect(cues[1].text, 'Second line');
    });

    test('parses MM:SS.mmm cues and strips tags', () {
      const vtt = '''
WEBVTT

01:02.500 --> 01:05.000
<c>Hello</c> <b>there</b>
''';
      final cues = parseWebVtt(vtt);
      expect(cues, hasLength(1));
      expect(cues[0].start, const Duration(seconds: 62, milliseconds: 500));
      expect(cues[0].text, 'Hello there');
    });

    test('skips NOTE blocks and cue identifiers', () {
      const vtt = '''
WEBVTT

NOTE this is a comment
spanning two lines

cue-1
00:00:00.000 --> 00:00:02.000
Only real cue
''';
      final cues = parseWebVtt(vtt);
      expect(cues, hasLength(1));
      expect(cues[0].text, 'Only real cue');
    });

    test('handles CRLF and multi-line cue text', () {
      const vtt =
          'WEBVTT\r\n\r\n00:00:01.000 --> 00:00:03.000\r\nline one\r\nline two\r\n';
      final cues = parseWebVtt(vtt);
      expect(cues, hasLength(1));
      expect(cues[0].text, 'line one\nline two');
    });

    test('returns empty list for garbage input', () {
      expect(parseWebVtt('not a vtt file'), isEmpty);
      expect(parseWebVtt(''), isEmpty);
    });

    test('parses fractional seconds of 1 and 2 digits', () {
      const vtt = '''
WEBVTT

00:00:01.5 --> 00:00:02.25
frac
''';
      final cues = parseWebVtt(vtt);
      expect(cues, hasLength(1));
      expect(cues[0].start, const Duration(milliseconds: 1500));
      expect(cues[0].end, const Duration(milliseconds: 2250));
    });
  });

  group('activeCaptionText', () {
    final cues = parseWebVtt('''
WEBVTT

00:00:01.000 --> 00:00:03.000
first

00:00:05.000 --> 00:00:07.000
second
''');

    test('returns cue active at position', () {
      expect(activeCaptionText(cues, const Duration(seconds: 2)), 'first');
      expect(activeCaptionText(cues, const Duration(seconds: 6)), 'second');
    });

    test('returns null in gaps and at exact end boundary', () {
      expect(activeCaptionText(cues, const Duration(seconds: 4)), isNull);
      expect(activeCaptionText(cues, const Duration(seconds: 3)), isNull);
      expect(activeCaptionText(cues, Duration.zero), isNull);
    });

    test('start boundary is inclusive', () {
      expect(activeCaptionText(cues, const Duration(seconds: 1)), 'first');
    });

    test('empty cue list returns null', () {
      expect(activeCaptionText(const [], const Duration(seconds: 1)), isNull);
    });
  });

  group('CaptionCue.contains', () {
    const cue = CaptionCue(
      start: Duration(seconds: 10),
      end: Duration(seconds: 12),
      text: 'x',
    );

    test('boundaries', () {
      expect(cue.contains(const Duration(seconds: 10)), isTrue);
      expect(cue.contains(const Duration(seconds: 11)), isTrue);
      expect(cue.contains(const Duration(seconds: 12)), isFalse);
      expect(cue.contains(const Duration(seconds: 9)), isFalse);
    });
  });
}
