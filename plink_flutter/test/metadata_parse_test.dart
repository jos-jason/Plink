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

  test('finds Amazon product photos, which have no og:image', () {
    final doc = html_parser.parse('''
<html><head><title>Amazon.com: Laptop</title>
<link rel="icon" href="https://www.amazon.com/favicon.ico"></head><body>
  <img src="https://m.media-amazon.com/images/G/01/gno/sprites/nav-sprite-global.png">
  <img src="https://m.media-amazon.com/images/I/317kEbusAZL._AC_SR38,50_.jpg" width="38" height="50">
  <img id="landingImage" src="https://m.media-amazon.com/images/I/61fd2oCrvyL._AC_SX342_SY445_QL70_ML2_.jpg"
       data-old-hires="https://m.media-amazon.com/images/I/61fd2oCrvyL._AC_SL1500_.jpg"
       data-a-dynamic-image='{"https://m.media-amazon.com/images/I/61fd2oCrvyL._AC_SX466_.jpg":[466,600]}'>
  <script>var data = {"colorImages": {"initial": [
    {"hiRes":"https://m.media-amazon.com/images/I/71ZAeHYYlHL._AC_SL1500_.jpg"},
    {"hiRes":"https://m.media-amazon.com/images/I/61C9irOOQVL._AC_SL1500_.jpg"}]}};</script>
  <img src="https://fls-na.amazon.com/1/batch/1/OP/ATVPDKIKX0DER:pixel.gif">
</body></html>''');
    final page = MetadataService.parsePage(
      doc,
      Uri.parse('https://www.amazon.com/dp/B0BSHF7WHW'),
    );
    expect(
      page.primaryImage.toString(),
      'https://m.media-amazon.com/images/I/61fd2oCrvyL.jpg',
    );
    expect(page.images.map((u) => u.toString()), [
      'https://m.media-amazon.com/images/I/61fd2oCrvyL.jpg',
      'https://m.media-amazon.com/images/I/71ZAeHYYlHL.jpg',
      'https://m.media-amazon.com/images/I/61C9irOOQVL.jpg',
    ]);
  });

  test('reads JSON-LD, srcset and lazy images', () {
    final doc = html_parser.parse('''
<script type="application/ld+json">{"@type":"Product","image":["https://shop.test/p1.jpg"]}</script>
<img data-src="/lazy.jpg" src="/placeholder-loading.gif">
<img srcset="/s-400.jpg 400w, /s-1200.jpg 1200w">
<img src="/spacer.png" width="1" height="1">''');
    final page = MetadataService.parsePage(
      doc,
      Uri.parse('https://shop.test/x'),
    );
    expect(page.primaryImage.toString(), 'https://shop.test/p1.jpg');
    expect(page.images.map((u) => u.toString()), [
      'https://shop.test/p1.jpg',
      'https://shop.test/lazy.jpg',
      'https://shop.test/s-1200.jpg',
    ]);
  });
}
