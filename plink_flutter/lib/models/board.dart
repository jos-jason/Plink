import 'package:uuid/uuid.dart';

import 'board_icons.dart';

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

  /// Icon key: an SF Symbol name, so values mean the same in the Swift app.
  /// See [boardIconCatalog] for what each key draws here.
  String icon;

  /// The icon to draw. A board left on the default folder gets the icon
  /// its name suggests ("Recipes" shows a fork and knife), without
  /// changing what's stored.
  BoardIcon get boardIcon {
    final chosen = boardIconForKey(icon);
    if (chosen != null && chosen.key != 'folder') return chosen;
    return suggestBoardIcon(name) ?? boardIconCatalog.first;
  }

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
