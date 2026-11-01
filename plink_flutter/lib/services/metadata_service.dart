import 'dart:convert';
import 'dart:typed_data';

import 'package:html/dom.dart';
import 'package:html/parser.dart' as html_parser;
import 'package:http/http.dart' as http;

import '../constants.dart';

class PinMetadata {
  const PinMetadata({
    this.title = '',
    this.description = '',
    required this.domain,
    this.imageData,
    this.availableImageUrls = const [],
    this.faviconData,
  });

  final String title;
  final String description;
  final String domain;

  /// The page's primary (Open Graph / Twitter) image
  final Uint8List? imageData;

  /// All image URLs found on the page (OG images, <img> tags)
  final List<Uri> availableImageUrls;

  /// Favicon data, used as a fallback when there is no main image
  final Uint8List? faviconData;
}

/// Replaces the Swift app's LinkPresentation-based fetcher with plain HTML
/// parsing, which works the same on every platform.
class MetadataService {
  MetadataService({http.Client? client}) : _client = client ?? http.Client();

  final http.Client _client;

  static const _headers = {
    // Some sites serve stripped-down or blocked pages to unknown agents.
    'User-Agent':
        'Mozilla/5.0 (Macintosh; Intel Mac OS X 10_15_7) AppleWebKit/605.1.15 '
        '(KHTML, like Gecko) Version/18.0 Safari/605.1.15',
    'Accept': 'text/html,application/xhtml+xml,*/*;q=0.8',
  };

  static const _timeout = Duration(seconds: 15);

  Future<PinMetadata> fetchMetadata(Uri url) async {
    final response = await _client
        .get(url, headers: _headers)
        .timeout(_timeout);
    if (response.statusCode >= 400) {
      throw http.ClientException('HTTP ${response.statusCode}', url);
    }
    final document = html_parser.parse(_decodeBody(response));
    final parsed = parsePage(document, url);

    Uint8List? imageData;
    if (parsed.primaryImage != null) {
      imageData = await downloadImage(parsed.primaryImage!);
    }

    Uint8List? faviconData;
    for (final candidate in [
      ?parsed.favicon,
      url.replace(path: '/favicon.ico', query: null, fragment: null),
    ]) {
      faviconData = await downloadImage(candidate);
      if (faviconData != null) break;
    }

    return PinMetadata(
      title: parsed.title,
      description: parsed.description,
      domain: url.displayDomain,
      imageData: imageData,
      availableImageUrls: parsed.images,
      faviconData: faviconData,
    );
  }

  /// Downloads image bytes, returning null for errors and non-image
  /// responses (e.g. HTML error pages).
  Future<Uint8List?> downloadImage(Uri url) async {
    try {
      final response = await _client
          .get(url, headers: _headers)
          .timeout(_timeout);
      if (response.statusCode >= 400) return null;
      final contentType = response.headers['content-type'] ?? '';
      if (contentType.startsWith('text/')) return null;
      final bytes = response.bodyBytes;
      if (bytes.isEmpty || isHtmlData(bytes)) return null;
      return bytes;
    } catch (_) {
      return null;
    }
  }

  static String _decodeBody(http.Response response) {
    // http defaults to latin1 without a charset; most pages are UTF-8.
    try {
      return utf8.decode(response.bodyBytes);
    } on FormatException {
      return response.body;
    }
  }

  static bool isHtmlData(List<int> data) {
    if (data.length < 5) return false;
    final header = String.fromCharCodes(data.take(15)).toLowerCase().trimLeft();
    return header.startsWith('<!doc') ||
        header.startsWith('<html') ||
        header.startsWith('<head');
  }

  /// Pure HTML extraction, separated out for testing.
  static ParsedPage parsePage(Document document, Uri baseUrl) {
    String? meta(List<String> names) {
      for (final name in names) {
        final el =
            document.querySelector('meta[property="$name"]') ??
            document.querySelector('meta[name="$name"]');
        final content = el?.attributes['content']?.trim();
        if (content != null && content.isNotEmpty) return content;
      }
      return null;
    }

    final title =
        meta(['og:title', 'twitter:title']) ??
        document.querySelector('title')?.text.trim() ??
        '';
    final description =
        meta(['og:description', 'twitter:description', 'description']) ?? '';

    final images = <Uri>[];
    final seen = <String>{};
    void addImage(String? src) {
      if (src == null || src.isEmpty) return;
      if (src.startsWith('data:') || src.toLowerCase().endsWith('.svg')) return;
      final resolved = _resolve(src, baseUrl);
      if (resolved != null && seen.add(resolved.toString())) {
        images.add(resolved);
      }
    }

    for (final el in document.querySelectorAll('meta')) {
      final key = el.attributes['property'] ?? el.attributes['name'];
      if (key == 'og:image' ||
          key == 'og:image:url' ||
          key == 'twitter:image') {
        addImage(el.attributes['content']?.trim());
      }
    }
    final primaryImage = images.isEmpty ? null : images.first;
    for (final el in document.querySelectorAll('img')) {
      addImage(el.attributes['src']?.trim());
    }

    // Prefer apple-touch-icon (larger) over a standard icon.
    Uri? favicon;
    var bestSize = 0;
    for (final el in document.querySelectorAll('link[rel]')) {
      final rel = el.attributes['rel']!.toLowerCase();
      if (!rel.contains('icon')) continue;
      final size = rel.contains('apple-touch') ? 180 : 32;
      final href = el.attributes['href'];
      if (size > bestSize && href != null) {
        final resolved = _resolve(href.trim(), baseUrl);
        if (resolved != null) {
          favicon = resolved;
          bestSize = size;
        }
      }
    }

    return ParsedPage(
      title: _collapseWhitespace(title),
      description: _collapseWhitespace(description),
      primaryImage: primaryImage,
      images: images.take(20).toList(),
      favicon: favicon,
    );
  }

  static Uri? _resolve(String src, Uri base) {
    try {
      final resolved = base.resolve(src);
      return resolved.scheme.startsWith('http') ? resolved : null;
    } on FormatException {
      return null;
    }
  }

  static String _collapseWhitespace(String s) =>
      s.replaceAll(RegExp(r'\s+'), ' ').trim();
}

class ParsedPage {
  const ParsedPage({
    required this.title,
    required this.description,
    required this.primaryImage,
    required this.images,
    required this.favicon,
  });

  final String title;
  final String description;
  final Uri? primaryImage;
  final List<Uri> images;
  final Uri? favicon;
}
