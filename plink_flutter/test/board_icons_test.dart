import 'package:flutter_test/flutter_test.dart';
import 'package:plink/models/board.dart';
import 'package:plink/models/board_icons.dart';

void main() {
  // The boards in the iOS app, and the icon each name should suggest.
  const expected = {
    'Kids': 'Kids',
    'Events': 'Events',
    'Books': 'Books',
    'Dimahs': 'Medicine',
    'Tools': 'Tools',
    'Crafts': 'Crafts',
    'Technology': 'Technology',
    'Plants': 'Plants',
    '3D Printing': '3D printing',
    'Tiny house': 'Tiny house',
    'AI tools': 'AI',
    'Recipes': 'Recipes',
    'Cloths': 'Clothes',
    'Temp': 'Temp',
    'TSE': 'School',
    'Info': 'Info',
    'Food': 'Food',
    'Design architecture': 'Architecture',
    'Home and decor': 'Home & decor',
    "Cassox's house": 'House',
    'Campers and trailers': 'Campers',
    'Fitness': 'Fitness',
    'News and magazines': 'News',
    'Travle': 'Travel',
    'Backpacking': 'Backpacking',
    'Actually buy?': 'Maybe buy',
    'Videos': 'Videos',
    'baselit': 'Baselit',
    'Boats': 'Boats',
  };

  test('every board name suggests its icon', () {
    final got = {
      for (final name in expected.keys) name: suggestBoardIcon(name)?.label,
    };
    expect(got, expected);
  });

  test('specific words beat broad ones', () {
    expect(suggestBoardIcon('Camping trips')?.label, 'Camping');
    expect(suggestBoardIcon('Backpacking gear')?.label, 'Backpacking');
    expect(suggestBoardIcon('Kitchen design')?.label, 'Kitchen');
    expect(suggestBoardIcon('Garage tools')?.label, 'Workshop');
  });

  test('catalog keys are unique', () {
    final keys = boardIconCatalog.map((i) => i.key).toList();
    expect(keys.toSet(), hasLength(keys.length));
  });

  test('a chosen icon wins over the name; folder falls back to the name', () {
    expect(
      Board(name: 'Recipes', icon: 'sailboat.fill').boardIcon.key,
      'sailboat.fill',
    );
    expect(Board(name: 'Recipes').boardIcon.key, 'fork.knife');
    expect(Board(name: 'Odds and ends').boardIcon.key, 'folder');
  });

  test('custom glyphs replace the old 3D printing and tiny house icons', () {
    expect(suggestBoardIcon('baselit')?.key, 'custom.baselit');
    expect(suggestBoardIcon('3D Printing')?.svg, isNotNull);
    expect(boardIconForKey('cube')?.key, 'custom.3dprinter');
    expect(boardIconForKey('house.lodge')?.key, 'custom.tinyhouse');
  });
}
