import 'package:flutter/material.dart';
import 'package:uuid/uuid.dart';

class Board {
  Board({
    String? id,
    required this.name,
    DateTime? dateCreated,
    DateTime? dateModified,
    this.sortOrder = 0,
    this.icon = 'folder',
  }) : id = id ?? const Uuid().v4().toUpperCase(),
       dateCreated = dateCreated ?? DateTime.now(),
       dateModified = dateModified ?? DateTime.now();

  final String id;
  String name;
  DateTime dateCreated;
  DateTime dateModified;
  int sortOrder;

  /// Icon key. Uses the Swift app's SF Symbol names so values round-trip;
  /// see [boardIcons] for the Material equivalents.
  String icon;

  IconData get iconData => boardIcons[icon] ?? Icons.folder_outlined;

  Map<String, dynamic> toJson() => {
    'id': id,
    'name': name,
    'dateCreated': dateCreated.toUtc().toIso8601String(),
    'dateModified': dateModified.toUtc().toIso8601String(),
    'sortOrder': sortOrder,
    'icon': icon,
  };

  factory Board.fromJson(Map<String, dynamic> json) => Board(
    id: json['id'] as String,
    name: json['name'] as String,
    dateCreated: DateTime.parse(json['dateCreated'] as String).toLocal(),
    dateModified: DateTime.parse(json['dateModified'] as String).toLocal(),
    sortOrder: json['sortOrder'] as int? ?? 0,
    icon: json['icon'] as String? ?? 'folder',
  );
}

/// SF Symbol name → Material icon, covering the Swift app's default icon set.
const Map<String, IconData> boardIcons = {
  'folder': Icons.folder_outlined,
  'star': Icons.star_outline,
  'heart': Icons.favorite_outline,
  'book': Icons.menu_book_outlined,
  'camera': Icons.photo_camera_outlined,
  'music.note': Icons.music_note_outlined,
  'cart': Icons.shopping_cart_outlined,
  'briefcase': Icons.work_outline,
  'house': Icons.home_outlined,
  'gamecontroller': Icons.sports_esports_outlined,
  'airplane': Icons.flight_outlined,
  'leaf': Icons.eco_outlined,
  'paintbrush': Icons.brush_outlined,
  'film': Icons.movie_outlined,
  'globe': Icons.public,
  'lightbulb': Icons.lightbulb_outline,
  'hammer': Icons.handyman_outlined,
  'wrench': Icons.build_outlined,
  'fork.knife': Icons.restaurant_outlined,
  'cup.and.saucer': Icons.local_cafe_outlined,
  'tshirt': Icons.checkroom_outlined,
  'shoe': Icons.directions_walk,
  'figure.run': Icons.directions_run,
  'bicycle': Icons.pedal_bike_outlined,
  'car': Icons.directions_car_outlined,
  'graduationcap': Icons.school_outlined,
  'theatermasks': Icons.theater_comedy_outlined,
  'trophy': Icons.emoji_events_outlined,
  'gift': Icons.card_giftcard_outlined,
  'bookmark': Icons.bookmark_outline,
  'flag': Icons.flag_outlined,
  'mappin': Icons.place_outlined,
  'tag': Icons.sell_outlined,
  'bell': Icons.notifications_outlined,
  'sparkles': Icons.auto_awesome_outlined,
};
