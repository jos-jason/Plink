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

    // Image candidates, best first: declared previews, structured data,
    // known product-photo slots, gallery data in scripts, then <img> tags.
    final images = <Uri>[];
    final seen = <String>{};
    bool addImage(String? src) {
      final url = _imageUrl(src, baseUrl);
      if (url == null || !seen.add(url.toString())) return false;
      images.add(url);
      return true;
    }

    for (final el in document.querySelectorAll('meta')) {
      final key = (el.attributes['property'] ?? el.attributes['name'] ?? '')
          .toLowerCase();
      if (const {
            'og:image',
            'og:image:url',
            'og:image:secure_url',
            'twitter:image',
            'twitter:image:src',
          }.contains(key) ||
          el.attributes['itemprop'] == 'image') {
        addImage(el.attributes['content']);
      }
    }
    for (final el in document.querySelectorAll('link[rel="image_src"]')) {
      addImage(el.attributes['href']);
    }
    for (final el in document.querySelectorAll(
      'script[type="application/ld+json"]',
    )) {
      _jsonLdImages(el.text).forEach(addImage);
    }
    // Amazon (and similar shops) put the product photo here, with no
    // og:image at all.
    for (final el in document.querySelectorAll(
      '#landingImage, #imgBlkFront, #ebooksImgBlkFront, #main-image',
    )) {
      addImage(el.attributes['data-old-hires']);
      addImage(_largestDynamicImage(el.attributes['data-a-dynamic-image']));
      addImage(el.attributes['src']);
    }
    for (final el in document.querySelectorAll('script')) {
      for (final m in _galleryPattern.allMatches(el.text)) {
        addImage(m.group(1));
      }
    }
    final primaryImage = images.isEmpty ? null : images.first;

    Uri? largeImg;
    for (final el in document.querySelectorAll('img')) {
      final a = el.attributes;
      if (_tooSmall(a['width']) || _tooSmall(a['height'])) continue;
      final src =
          a['data-old-hires'] ??
          _largestSrcset(a['srcset'] ?? a['data-srcset']) ??
          a['data-src'] ??
          a['data-lazy-src'] ??
          a['src'];
      if (addImage(src) && largeImg == null && _isLarge(a)) {
        largeImg = images.last;
      }
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
      // A page with no declared image can still have an obviously large one.
      primaryImage: primaryImage ?? largeImg,
      images: images.take(24).toList(),
      favicon: favicon,
    );
  }

  static final _galleryPattern = RegExp(
    r'"(?:hiRes|large|mainUrl)"\s*:\s*"(https?://[^"]+)"',
  );

  static final _skipPattern = RegExp(
    r'sprite|pixel|spacer|1x1|blank\.gif|transparent\.|/favicon|loading\.gif',
    caseSensitive: false,
  );

  /// Resolves an image src, dropping data URIs, SVGs and obvious non-photos,
  /// and upgrading Amazon thumbnails to the full-size image.
  static Uri? _imageUrl(String? src, Uri base) {
    final s = src?.trim();
    if (s == null || s.isEmpty || s.startsWith('data:')) return null;
    final url = _resolve(s, base);
    if (url == null) return null;
    final path = url.path.toLowerCase();
    if (path.endsWith('.svg') || path.endsWith('.gif')) return null;
    if (_skipPattern.hasMatch(url.toString())) return null;
    return _fullSizeAmazon(url);
  }

  /// m.media-amazon.com/images/I/61fd2oCrvyL._AC_SX342_SY445_.jpg names a
  /// resized copy; without the `._…_` part it's the original photo.
  static Uri _fullSizeAmazon(Uri url) {
    if (!url.host.endsWith('media-amazon.com') &&
        !url.host.endsWith('ssl-images-amazon.com')) {
      return url;
    }
    if (!url.path.contains('/images/I/')) return url;
    return url.replace(
      path: url.path.replaceFirstMapped(
        RegExp(r'\._[^/]*_\.(jpe?g|png|webp)$'),
        (m) => '.${m[1]}',
      ),
    );
  }

  /// `data-a-dynamic-image` is JSON: {"url": [width, height], ...}.
  static String? _largestDynamicImage(String? json) {
    if (json == null) return null;
    try {
      final map = (jsonDecode(json) as Map).cast<String, dynamic>();
      String? best;
      var bestArea = 0;
      map.forEach((url, size) {
        final area = size is List && size.length == 2
            ? (size[0] as num).toInt() * (size[1] as num).toInt()
            : 0;
        if (area >= bestArea) {
          best = url;
          bestArea = area;
        }
      });
      return best;
    } catch (_) {
      return null;
    }
  }

  static String? _largestSrcset(String? srcset) {
    if (srcset == null || srcset.trim().isEmpty) return null;
    String? best;
    var bestW = -1.0;
    for (final part in srcset.split(',')) {
      final bits = part.trim().split(RegExp(r'\s+'));
      if (bits.isEmpty || bits.first.isEmpty) continue;
      final w = bits.length > 1
          ? double.tryParse(bits[1].replaceAll(RegExp(r'[wx]'), '')) ?? 0
          : 0.0;
      if (w >= bestW) {
        best = bits.first;
        bestW = w;
      }
    }
    return best;
  }

  /// Image URLs from schema.org JSON-LD (`"image": url | [urls] | {url}`).
  static List<String> _jsonLdImages(String text) {
    final out = <String>[];
    void walk(Object? node) {
      if (node is Map) {
        final image = node['image'];
        if (image is String) out.add(image);
        if (image is List) {
          for (final i in image) {
            if (i is String) out.add(i);
            if (i is Map && i['url'] is String) out.add(i['url'] as String);
          }
        }
        if (image is Map && image['url'] is String) {
          out.add(image['url'] as String);
        }
        node.values.forEach(walk);
      } else if (node is List) {
        node.forEach(walk);
      }
    }

    try {
      walk(jsonDecode(text));
    } catch (_) {}
    return out;
  }

  static bool _tooSmall(String? dimension) {
    final v = int.tryParse(dimension ?? '');
    return v != null && v < 80;
  }

  static bool _isLarge(Map<Object, String> attrs) {
    final w = int.tryParse(attrs['width'] ?? '') ?? 0;
    final h = int.tryParse(attrs['height'] ?? '') ?? 0;
    return w >= 200 && h >= 150;
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
