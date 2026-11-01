import 'package:flutter/material.dart';

abstract final class AppConstants {
  static const cardCornerRadius = 12.0;
  static const cardSpacing = 12.0;
  static const cardPadding = 10.0;
  static const paginationBatchSize = 40;
  static const imageJpegQuality = 80;
  static const maxImageWidth = 600;
  static const imageDirectoryName = 'PinImages';
  static const libraryFileName = 'library.json';

  /// Matches the Swift app's AccentColor asset.
  static const accentColor = Color(0xFFD88A1A);

  /// Width below which the app uses bottom tabs instead of a sidebar.
  static const compactBreakpoint = 600.0;

  /// Masonry column count for a given content width.
  static int columnsForWidth(double width) {
    if (width < 500) return 2;
    if (width < 800) return 3;
    if (width < 1200) return 4;
    return 5;
  }
}

extension UrlHelpers on Uri {
  /// "apple.com" from "https://www.apple.com/path"
  String get displayDomain =>
      host.startsWith('www.') ? host.substring(4) : host;
}

extension UrlStringHelpers on String {
  /// Adds "https://" when no scheme is present.
  String get normalizedUrlString {
    final trimmed = trim();
    if (trimmed.startsWith('http://') || trimmed.startsWith('https://')) {
      return trimmed;
    }
    return 'https://$trimmed';
  }

  bool get isValidUrl {
    final uri = Uri.tryParse(this);
    return uri != null &&
        (uri.scheme == 'http' || uri.scheme == 'https') &&
        uri.host.contains('.');
  }
}
