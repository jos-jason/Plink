import 'package:uuid/uuid.dart';

/// A saved link. Mirrors the Swift app's `Pin` model, with board membership
/// stored as a list of board IDs instead of a SwiftData relationship.
class Pin {
  Pin({
    String? id,
    required this.urlString,
    this.title = '',
    this.pageDescription = '',
    this.domain = '',
    DateTime? dateAdded,
    DateTime? dateModified,
    this.imagePath,
    this.faviconPath,
    this.isCustomImage = false,
    this.metadataFetched = false,
    List<String>? boardIds,
    this.notes = '',
    this.imageAspectRatio = 1.5,
    this.sortOrder = 0,
  }) : id = id ?? const Uuid().v4().toUpperCase(),
       dateAdded = dateAdded ?? DateTime.now(),
       dateModified = dateModified ?? DateTime.now(),
       boardIds = boardIds ?? [];

  /// Uppercase UUID string, matching Swift's `UUID.uuidString`.
  final String id;
  String urlString;
  String title;
  String pageDescription;
  String domain;
  DateTime dateAdded;
  DateTime dateModified;

  /// Filename of the stored image within PinImages/
  String? imagePath;

  /// Filename of the stored favicon within PinImages/
  String? faviconPath;

  /// Whether the user manually chose/uploaded this image
  bool isCustomImage;

  /// Whether metadata has been fetched (distinguishes "no metadata" from "not yet attempted")
  bool metadataFetched;

  List<String> boardIds;
  String notes;

  /// Aspect ratio of the stored image (width / height), used for layout sizing
  double imageAspectRatio;

  /// User-defined sort order within a board
  int sortOrder;

  Uri? get url => Uri.tryParse(urlString);

  Map<String, dynamic> toJson() => {
    'id': id,
    'urlString': urlString,
    'title': title,
    'pageDescription': pageDescription,
    'domain': domain,
    'dateAdded': dateAdded.toUtc().toIso8601String(),
    'dateModified': dateModified.toUtc().toIso8601String(),
    'imagePath': imagePath,
    'faviconPath': faviconPath,
    'isCustomImage': isCustomImage,
    'metadataFetched': metadataFetched,
    'boardIds': boardIds,
    'notes': notes,
    'imageAspectRatio': imageAspectRatio,
    'sortOrder': sortOrder,
  };

  factory Pin.fromJson(Map<String, dynamic> json) => Pin(
    id: json['id'] as String,
    urlString: json['urlString'] as String,
    title: json['title'] as String? ?? '',
    pageDescription: json['pageDescription'] as String? ?? '',
    domain: json['domain'] as String? ?? '',
    dateAdded: DateTime.parse(json['dateAdded'] as String).toLocal(),
    dateModified: DateTime.parse(json['dateModified'] as String).toLocal(),
    imagePath: json['imagePath'] as String?,
    faviconPath: json['faviconPath'] as String?,
    isCustomImage: json['isCustomImage'] as bool? ?? false,
    metadataFetched: json['metadataFetched'] as bool? ?? false,
    boardIds: (json['boardIds'] as List?)?.cast<String>().toList(),
    notes: json['notes'] as String? ?? '',
    imageAspectRatio: (json['imageAspectRatio'] as num?)?.toDouble() ?? 1.5,
    sortOrder: json['sortOrder'] as int? ?? 0,
  );
}
