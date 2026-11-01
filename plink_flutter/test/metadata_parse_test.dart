import 'package:flutter_test/flutter_test.dart';
import 'package:html/parser.dart' as html_parser;
import 'package:plink/services/metadata_service.dart';

void main() {
  final base = Uri.parse('https://www.example.com/articles/soup');

  test('extracts OG metadata, images and the best favicon', () {
    final doc = html_parser.parse('''
<html><head>
  <title>Fallback Title</title>
  <meta content="Tomato   Soup" property="og:title">
  <meta name="description" content="A warm soup.">
  <meta property="og:image" content="/img/hero.jpg">
  <link rel="icon" href="/favicon-32.png">
  <link rel="apple-touch-icon" href="/touch.png">
</head><body>
  <img src="photo.jpg"><img src="data:image/png;base64,xx"><img src="logo.svg">
  <img src="/img/hero.jpg">
</body></html>''');
    final page = MetadataService.parsePage(doc, base);
    expect(page.title, 'Tomato Soup');
    expect(page.description, 'A warm soup.');
    expect(
      page.primaryImage.toString(),
      'https://www.example.com/img/hero.jpg',
    );
    expect(page.images.map((u) => u.toString()), [
      'https://www.example.com/img/hero.jpg',
      'https://www.example.com/articles/photo.jpg',
    ]);
    expect(page.favicon.toString(), 'https://www.example.com/touch.png');
  });

  test('falls back to <title> with no OG tags', () {
    final page = MetadataService.parsePage(
      html_parser.parse('<title> Plain </title>'),
      base,
    );
    expect(page.title, 'Plain');
    expect(page.primaryImage, isNull);
    expect(page.favicon, isNull);
  });

  test('detects HTML masquerading as an image', () {
    expect(
      MetadataService.isHtmlData('<!DOCTYPE html><html>'.codeUnits),
      isTrue,
    );
    expect(
      MetadataService.isHtmlData([0x89, 0x50, 0x4E, 0x47, 0x0D, 0x0A]),
      isFalse,
    );
  });
}
