import 'dart:convert';
import 'dart:io';

/// Run from the repository root after editing PRIVACY.md.
void main() {
  const escape = HtmlEscape();
  final paragraphs = File('PRIVACY.md')
      .readAsStringSync()
      .replaceAll('\r\n', '\n')
      .trim()
      .split('\n\n');
  final content = StringBuffer();
  for (final paragraph in paragraphs) {
    final heading = paragraph.startsWith('# ')
        ? 1
        : paragraph.startsWith('## ')
        ? 2
        : 0;
    final text = escape.convert(
      heading == 0
          ? paragraph.replaceAll('\n', ' ')
          : paragraph.substring(heading + 1),
    );
    final tag = heading == 0 ? 'p' : 'h$heading';
    content.writeln('<$tag>$text</$tag>');
  }
  File('docs/privacy.html').writeAsStringSync('''<!doctype html>
<!-- Generated from PRIVACY.md by tool/generate_privacy_page.dart. -->
<html lang="en"><head><meta charset="utf-8">
<meta name="viewport" content="width=device-width,initial-scale=1">
<title>AttendX Privacy Policy</title>
<style>body{max-width:760px;margin:40px auto;padding:0 20px;font:18px/1.6 system-ui,sans-serif;color:#1d1d1f;background:#fff}h1{font-size:2rem}h2{margin-top:2rem;font-size:1.3rem}p{overflow-wrap:anywhere}</style>
</head><body><main>$content</main></body></html>
''');
}
