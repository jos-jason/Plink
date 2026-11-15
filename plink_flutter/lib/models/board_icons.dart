import 'package:flutter/widgets.dart';

import 'custom_glyphs.dart';

/// One choice in the board icon picker.
///
/// [key] is the SF Symbol name the Swift app uses for the same idea, so a
/// board's `icon` value means the same thing in both apps. [icon] is the
/// Phosphor glyph drawn here: Phosphor's clean, rounded set is the closest
/// match to SF Symbols that can ship on Android and Linux. Filled glyphs
/// are used where the iOS app's icons are filled.
class BoardIcon {
  const BoardIcon(this.key, this.label, IconData this.icon, this.keywords)
    : svg = null;

  /// A glyph drawn for Plink (see custom_glyphs.dart) rather than a font icon.
  /// The key is still the matching SF Symbol name when there is one (so the
  /// Swift app shows its own version), or `custom.*` when there isn't.
  const BoardIcon.svg(this.key, this.label, String this.svg, this.keywords)
    : icon = null;

  final String key;
  final String label;

  /// Exactly one of [icon] and [svg] is set.
  final IconData? icon;
  final String? svg;

  /// Lower-case words that suggest this icon for a board name.
  final List<String> keywords;
}

/// Every icon a board can use, in picker order. The order also breaks ties
/// when matching names, so specific entries come before general ones
/// (e.g. "Tiny house" before "House", "AI tools" before "Tools").
const List<BoardIcon> boardIconCatalog = [
  BoardIcon('folder', 'Folder', _folderSimple, []),

  // ---- The boards in the iOS app ----
  BoardIcon.svg('figure.2.and.child.holdinghands', 'Kids', kidRunningGlyph, [
    'kid',
    'kids',
    'child',
    'children',
    'family',
    'baby',
    'toddler',
    'parenting',
  ]),
  BoardIcon('calendar', 'Events', _calendarDots, [
    'event',
    'events',
    'calendar',
    'concert',
    'festival',
    'schedule',
  ]),
  BoardIcon('books.vertical.fill', 'Books', _booksFill, [
    'book',
    'books',
    'reading',
    'library',
    'novel',
    'novels',
  ]),
  BoardIcon('pills.fill', 'Medicine', _pillFill, [
    'pill',
    'pills',
    'medicine',
    'meds',
    'vitamin',
    'vitamins',
    'supplement',
    'dimahs',
  ]),
  BoardIcon('sparkles', 'AI', _sparkle, [
    'ai',
    'gpt',
    'llm',
    'chatbot',
    'ml',
    'prompt',
    'prompts',
  ]),
  BoardIcon('wrench.adjustable', 'Tools', _wrench, [
    'tool',
    'tools',
    'repair',
    'fix',
    'maintenance',
  ]),
  BoardIcon('paintbrush.pointed', 'Crafts', _paintBrush, [
    'craft',
    'crafts',
    'crafting',
    'diy',
    'handmade',
  ]),
  BoardIcon('desktopcomputer', 'Technology', _devices, [
    'tech',
    'technology',
    'gadget',
    'gadgets',
    'computer',
    'computers',
  ]),
  BoardIcon('leaf.fill', 'Plants', _leafFill, [
    'plant',
    'plants',
    'houseplant',
    'houseplants',
    'succulent',
    'succulents',
  ]),
  BoardIcon.svg('custom.3dprinter', '3D printing', printer3dGlyph, [
    '3d',
    'printing',
    'printer',
    'cad',
    'model',
    'models',
  ]),
  BoardIcon.svg('custom.tinyhouse', 'Tiny house', tinyHouseGlyph, [
    'tiny',
    'cabin',
    'cabins',
    'lodge',
    'shed',
  ]),
  BoardIcon('fork.knife', 'Recipes', _forkKnife, [
    'recipe',
    'recipes',
    'cooking',
    'dinner',
    'dinners',
    'meal',
    'meals',
  ]),
  BoardIcon.svg('tshirt.fill', 'Clothes', tShirtGlyph, [
    'cloth',
    'cloths',
    'clothes',
    'clothing',
    'fashion',
    'outfit',
    'outfits',
    'style',
    'wardrobe',
  ]),
  BoardIcon('tray.full', 'Temp', _tray, [
    'temp',
    'temporary',
    'inbox',
    'misc',
    'later',
    'unsorted',
    'todo',
  ]),
  BoardIcon('graduationcap', 'School', _graduationCap, [
    'school',
    'class',
    'classes',
    'course',
    'courses',
    'study',
    'education',
    'learning',
    'university',
    'college',
    'tse',
  ]),
  BoardIcon('info.bubble', 'Info', _info, [
    'info',
    'information',
    'reference',
    'facts',
    'howto',
  ]),
  BoardIcon('carrot', 'Food', _bowlFood, [
    'food',
    'foods',
    'snack',
    'snacks',
    'eat',
    'eats',
    'nutrition',
  ]),
  BoardIcon('building.columns', 'Architecture', _buildings, [
    'architecture',
    'architect',
    'building',
    'buildings',
  ]),
  BoardIcon('lamp.desk.fill', 'Home & decor', _lampFill, [
    'home',
    'decor',
    'interior',
    'interiors',
    'lamp',
    'lighting',
  ]),
  BoardIcon('house.fill', 'House', _houseFill, [
    'house',
    'houses',
    'apartment',
    'place',
  ]),
  BoardIcon('bus.fill', 'Campers', _vanFill, [
    'camper',
    'campers',
    'trailer',
    'trailers',
    'rv',
    'van',
    'vanlife',
    'caravan',
    'overland',
    'overlanding',
  ]),
  BoardIcon.svg('dumbbell.fill', 'Fitness', flexedArmGlyph, [
    'fitness',
    'gym',
    'workout',
    'workouts',
    'exercise',
    'training',
    'strength',
  ]),
  BoardIcon('newspaper', 'News', _newspaper, [
    'news',
    'magazine',
    'magazines',
    'article',
    'articles',
    'journal',
  ]),
  BoardIcon('airplane', 'Travel', _airplaneTilt, [
    'travel',
    'travle',
    'trip',
    'trips',
    'vacation',
    'flight',
    'flights',
  ]),
  BoardIcon.svg('backpack.fill', 'Backpacking', backpackGlyph, [
    'backpack',
    'backpacking',
    'gear',
    'pack',
    'ultralight',
  ]),
  BoardIcon('cart.badge.clock', 'Maybe buy', _shoppingCart, [
    'buy',
    'cart',
    'purchase',
    'purchases',
    'want',
    'wants',
  ]),
  BoardIcon('play.rectangle', 'Videos', _playCircle, [
    'video',
    'videos',
    'youtube',
    'watch',
    'clip',
    'clips',
  ]),
  BoardIcon.svg('custom.baselit', 'Baselit', baselitGlyph, ['baselit']),
  BoardIcon('briefcase', 'Work', _briefcase, [
    'work',
    'job',
    'jobs',
    'business',
    'office',
    'project',
    'projects',
  ]),
  BoardIcon('sailboat.fill', 'Boats', _sailboatFill, [
    'boat',
    'boats',
    'sail',
    'sailing',
    'kayak',
    'canoe',
    'yacht',
  ]),

  // ---- Suggestions for boards you might add ----
  BoardIcon('frying.pan', 'Kitchen', _cookingPot, [
    'kitchen',
    'cookware',
    'pots',
  ]),
  BoardIcon('birthday.cake', 'Baking', _cake, [
    'bake',
    'baking',
    'cake',
    'cakes',
    'bread',
    'dessert',
    'desserts',
  ]),
  BoardIcon('cup.and.saucer', 'Coffee', _coffee, [
    'coffee',
    'cafe',
    'tea',
    'espresso',
  ]),
  BoardIcon('wineglass', 'Drinks', _wine, [
    'drink',
    'drinks',
    'cocktail',
    'cocktails',
    'wine',
    'beer',
  ]),
  BoardIcon('tree', 'Gardening', _shovel, [
    'garden',
    'gardening',
    'yard',
    'vegetable',
    'vegetables',
    'landscaping',
  ]),
  BoardIcon('hammer', 'Woodworking', _hammer, [
    'wood',
    'woodworking',
    'carpentry',
    'build',
    'builds',
  ]),
  BoardIcon('wrench.and.screwdriver', 'Workshop', _toolbox, [
    'workshop',
    'garage',
    'shop',
  ]),
  BoardIcon('paintbrush', 'Renovation', _paintRoller, [
    'renovation',
    'renovations',
    'remodel',
    'paint',
    'improvement',
  ]),
  BoardIcon('sofa', 'Furniture', _couch, [
    'furniture',
    'sofa',
    'couch',
    'chair',
    'chairs',
  ]),
  BoardIcon('archivebox', 'Organizing', _package, [
    'organize',
    'organizing',
    'organization',
    'storage',
    'declutter',
  ]),
  BoardIcon('cpu', 'Electronics', _circuitry, [
    'electronics',
    'arduino',
    'raspberry',
    'circuit',
    'circuits',
    'solder',
  ]),
  BoardIcon('sun.max', 'Off-grid & solar', _solarPanel, [
    'solar',
    'offgrid',
    'off',
    'grid',
    'energy',
    'battery',
    'batteries',
    'power',
  ]),
  BoardIcon('tent', 'Camping', _tent, [
    'camp',
    'camping',
    'tent',
    'campsite',
    'campsites',
  ]),
  BoardIcon('figure.hiking', 'Hiking', _personSimpleHike, [
    'hike',
    'hiking',
    'trail',
    'trails',
    'trek',
    'trekking',
  ]),
  BoardIcon('mountain.2', 'Outdoors', _mountains, [
    'outdoor',
    'outdoors',
    'nature',
    'mountain',
    'mountains',
    'climbing',
  ]),
  BoardIcon('water.waves', 'Ocean', _waves, [
    'ocean',
    'sea',
    'beach',
    'surf',
    'surfing',
    'diving',
    'swim',
  ]),
  BoardIcon('fish', 'Fishing', _fish, ['fish', 'fishing', 'fly']),
  BoardIcon('bicycle', 'Cycling', _bicycle, [
    'bike',
    'bikes',
    'cycling',
    'bicycle',
    'bicycles',
    'mtb',
  ]),
  BoardIcon('car', 'Cars', _car, [
    'car',
    'cars',
    'auto',
    'vehicle',
    'vehicles',
    'truck',
    'trucks',
  ]),
  BoardIcon('mappin', 'Places', _mapPin, [
    'places',
    'location',
    'locations',
    'visit',
    'spots',
    'map',
  ]),
  BoardIcon('music.note', 'Music', _musicNotes, [
    'music',
    'song',
    'songs',
    'band',
    'bands',
    'album',
    'albums',
    'guitar',
  ]),
  BoardIcon('film', 'Movies & TV', _filmSlate, [
    'movie',
    'movies',
    'film',
    'films',
    'tv',
    'show',
    'shows',
    'series',
  ]),
  BoardIcon('gamecontroller', 'Games', _gameController, [
    'game',
    'games',
    'gaming',
    'videogames',
  ]),
  BoardIcon('camera', 'Photography', _camera, [
    'photo',
    'photos',
    'photography',
    'camera',
    'cameras',
  ]),
  BoardIcon('paintpalette', 'Art', _palette, [
    'art',
    'painting',
    'drawing',
    'illustration',
    'artists',
  ]),
  BoardIcon('scissors', 'Sewing', _scissors, [
    'sew',
    'sewing',
    'quilt',
    'quilting',
    'knit',
    'knitting',
    'pattern',
    'patterns',
  ]),
  BoardIcon('pawprint', 'Pets', _pawPrint, [
    'pet',
    'pets',
    'dog',
    'dogs',
    'cat',
    'cats',
    'puppy',
  ]),
  BoardIcon('cross.case', 'Health', _firstAid, [
    'health',
    'medical',
    'wellness',
    'doctor',
    'firstaid',
  ]),
  BoardIcon('dollarsign.circle', 'Money', _piggyBank, [
    'money',
    'finance',
    'finances',
    'budget',
    'invest',
    'investing',
    'savings',
  ]),
  BoardIcon('gift', 'Gifts', _gift, [
    'gift',
    'gifts',
    'present',
    'presents',
    'birthday',
    'birthdays',
  ]),
  BoardIcon('party.popper', 'Holidays', _confetti, [
    'holiday',
    'holidays',
    'christmas',
    'celebration',
    'party',
    'parties',
  ]),
  BoardIcon('bag', 'Shopping', _handbag, [
    'shopping',
    'store',
    'stores',
    'brand',
    'brands',
    'deals',
  ]),
  BoardIcon('star', 'Wishlist', _star, [
    'wishlist',
    'favorite',
    'favorites',
    'favourites',
    'best',
  ]),
  BoardIcon('lightbulb', 'Ideas', _lightbulb, [
    'idea',
    'ideas',
    'inspiration',
    'inspo',
  ]),
  BoardIcon('quote.bubble', 'Quotes', _quotes, [
    'quote',
    'quotes',
    'saying',
    'sayings',
  ]),
  BoardIcon('atom', 'Science', _atom, [
    'science',
    'physics',
    'chemistry',
    'biology',
  ]),
  BoardIcon('moon.stars', 'Space', _planet, [
    'space',
    'astronomy',
    'nasa',
    'planet',
    'planets',
    'stars',
  ]),
  BoardIcon('iphone', 'App design', _deviceMobile, [
    'app',
    'apps',
    'ui',
    'ux',
    'mobile',
    'design',
  ]),
  BoardIcon('chevron.left.forwardslash.chevron.right', 'Coding', _code, [
    'code',
    'coding',
    'programming',
    'dev',
    'software',
    'github',
  ]),
  BoardIcon('bookmark', 'Saved', _bookmarkSimple, [
    'saved',
    'bookmarks',
    'read',
    'reads',
  ]),
  BoardIcon('heart', 'Love', _heart, [
    'love',
    'loves',
    'wedding',
    'weddings',
    'date',
    'dates',
  ]),
];

final Map<String, BoardIcon> _byKey = {
  for (final i in boardIconCatalog) i.key: i,
};

/// Older keys from the first Flutter icon set (and other SF names the Swift
/// app's picker may have stored), mapped onto catalog entries.
const Map<String, String> _aliases = {
  'cube': 'custom.3dprinter',
  'printer': 'custom.3dprinter',
  'house.lodge': 'custom.tinyhouse',
  'folder.fill': 'folder',
  'book': 'books.vertical.fill',
  'books.vertical': 'books.vertical.fill',
  'leaf': 'leaf.fill',
  'tshirt': 'tshirt.fill',
  'house': 'house.fill',
  'pills': 'pills.fill',
  'paintbrush.pointed.fill': 'paintbrush.pointed',
  'music.note.list': 'music.note',
  'cart': 'cart.badge.clock',
  'mappin.and.ellipse': 'mappin',
  'globe': 'airplane',
  'brain': 'sparkles',
  'brain.head.profile': 'sparkles',
  'shoe': 'figure.hiking',
  'figure.run': 'dumbbell.fill',
  'graduationcap.fill': 'graduationcap',
  'bus': 'bus.fill',
  'backpack': 'backpack.fill',
  'sailboat': 'sailboat.fill',
  'lamp.desk': 'lamp.desk.fill',
  'tag': 'bookmark',
  'flag': 'star',
  'bell': 'calendar',
  'trophy': 'star',
  'theatermasks': 'film',
};

BoardIcon? boardIconForKey(String key) => _byKey[key] ?? _byKey[_aliases[key]];

/// Broad words that only decide the icon when nothing more specific
/// matches: "Camping trips" is camping, not travel; "AI tools" is AI.
const Set<String> _weakWords = {
  'trip',
  'trips',
  'tool',
  'tools',
  'house',
  'houses',
  'home',
  'design',
  'gear',
  'pack',
  'project',
  'projects',
  'work',
  'place',
  'show',
  'shows',
  'model',
  'models',
  'build',
  'builds',
  'want',
  'wants',
  'read',
  'reads',
};

/// The catalog entry that best fits a board [name], or null if none does.
BoardIcon? suggestBoardIcon(String name) {
  final words = name
      .toLowerCase()
      .replaceAll(RegExp(r"'s\b"), '')
      .split(RegExp(r'[^a-z0-9]+'))
      .where((w) => w.isNotEmpty && w != 'and' && w != 'the')
      .toSet();
  if (words.isEmpty) return null;
  final strong = words.difference(_weakWords);
  final weak = words.intersection(_weakWords);
  for (final pass in [strong, weak]) {
    for (final entry in boardIconCatalog) {
      for (final k in entry.keywords) {
        if (pass.contains(k)) return entry;
      }
    }
  }
  return null;
}

/// Picker search: matches labels and keywords.
List<BoardIcon> searchBoardIcons(String query) {
  final q = query.trim().toLowerCase();
  if (q.isEmpty) return boardIconCatalog;
  return [
    for (final i in boardIconCatalog)
      if (i.label.toLowerCase().contains(q) ||
          i.keywords.any((k) => k.startsWith(q)))
        i,
  ];
}

// ---- Phosphor glyphs ----
// Drawn from the fonts bundled in phosphor_flutter (2.1.0). That package's
// own icon class extends IconData, which current Flutter no longer allows,
// so its Dart API isn't imported; these are the same code points.
const _pkg = 'phosphor_flutter';
const _regularFont = 'PhosphorRegular';
const _fillFont = 'PhosphorFill';
const _booksFill = IconData(0xe758, fontFamily: _fillFont, fontPackage: _pkg);
const _houseFill = IconData(0xe2c2, fontFamily: _fillFont, fontPackage: _pkg);
const _lampFill = IconData(0xe638, fontFamily: _fillFont, fontPackage: _pkg);
const _leafFill = IconData(0xe2da, fontFamily: _fillFont, fontPackage: _pkg);
const _pillFill = IconData(0xe700, fontFamily: _fillFont, fontPackage: _pkg);
const _sailboatFill = IconData(
  0xe78a,
  fontFamily: _fillFont,
  fontPackage: _pkg,
);
const _vanFill = IconData(0xe826, fontFamily: _fillFont, fontPackage: _pkg);
const _airplaneTilt = IconData(
  0xe5d6,
  fontFamily: _regularFont,
  fontPackage: _pkg,
);
const _atom = IconData(0xe5e4, fontFamily: _regularFont, fontPackage: _pkg);
const _bicycle = IconData(0xe0d6, fontFamily: _regularFont, fontPackage: _pkg);
const _bookmarkSimple = IconData(
  0xe0ea,
  fontFamily: _regularFont,
  fontPackage: _pkg,
);
const _bowlFood = IconData(0xeaa4, fontFamily: _regularFont, fontPackage: _pkg);
const _briefcase = IconData(
  0xe0ee,
  fontFamily: _regularFont,
  fontPackage: _pkg,
);
const _buildings = IconData(
  0xe102,
  fontFamily: _regularFont,
  fontPackage: _pkg,
);
const _cake = IconData(0xe780, fontFamily: _regularFont, fontPackage: _pkg);
const _calendarDots = IconData(
  0xe7b4,
  fontFamily: _regularFont,
  fontPackage: _pkg,
);
const _camera = IconData(0xe10e, fontFamily: _regularFont, fontPackage: _pkg);
const _car = IconData(0xe112, fontFamily: _regularFont, fontPackage: _pkg);
const _circuitry = IconData(
  0xe9c2,
  fontFamily: _regularFont,
  fontPackage: _pkg,
);
const _code = IconData(0xe1bc, fontFamily: _regularFont, fontPackage: _pkg);
const _coffee = IconData(0xe1c2, fontFamily: _regularFont, fontPackage: _pkg);
const _confetti = IconData(0xe81a, fontFamily: _regularFont, fontPackage: _pkg);
const _cookingPot = IconData(
  0xe764,
  fontFamily: _regularFont,
  fontPackage: _pkg,
);
const _couch = IconData(0xe7f6, fontFamily: _regularFont, fontPackage: _pkg);
const _deviceMobile = IconData(
  0xe1e0,
  fontFamily: _regularFont,
  fontPackage: _pkg,
);
const _devices = IconData(0xeba4, fontFamily: _regularFont, fontPackage: _pkg);
const _filmSlate = IconData(
  0xe8c2,
  fontFamily: _regularFont,
  fontPackage: _pkg,
);
const _firstAid = IconData(0xe56e, fontFamily: _regularFont, fontPackage: _pkg);
const _fish = IconData(0xe728, fontFamily: _regularFont, fontPackage: _pkg);
const _folderSimple = IconData(
  0xe25a,
  fontFamily: _regularFont,
  fontPackage: _pkg,
);
const _forkKnife = IconData(
  0xe262,
  fontFamily: _regularFont,
  fontPackage: _pkg,
);
const _gameController = IconData(
  0xe26e,
  fontFamily: _regularFont,
  fontPackage: _pkg,
);
const _gift = IconData(0xe276, fontFamily: _regularFont, fontPackage: _pkg);
const _graduationCap = IconData(
  0xe62c,
  fontFamily: _regularFont,
  fontPackage: _pkg,
);
const _hammer = IconData(0xe80e, fontFamily: _regularFont, fontPackage: _pkg);
const _handbag = IconData(0xe29c, fontFamily: _regularFont, fontPackage: _pkg);
const _heart = IconData(0xe2a8, fontFamily: _regularFont, fontPackage: _pkg);
const _info = IconData(0xe2ce, fontFamily: _regularFont, fontPackage: _pkg);
const _lightbulb = IconData(
  0xe2dc,
  fontFamily: _regularFont,
  fontPackage: _pkg,
);
const _mapPin = IconData(0xe316, fontFamily: _regularFont, fontPackage: _pkg);
const _mountains = IconData(
  0xe7ae,
  fontFamily: _regularFont,
  fontPackage: _pkg,
);
const _musicNotes = IconData(
  0xe340,
  fontFamily: _regularFont,
  fontPackage: _pkg,
);
const _newspaper = IconData(
  0xe344,
  fontFamily: _regularFont,
  fontPackage: _pkg,
);
const _package = IconData(0xe390, fontFamily: _regularFont, fontPackage: _pkg);
const _paintBrush = IconData(
  0xe6f0,
  fontFamily: _regularFont,
  fontPackage: _pkg,
);
const _paintRoller = IconData(
  0xe6f4,
  fontFamily: _regularFont,
  fontPackage: _pkg,
);
const _palette = IconData(0xe6c8, fontFamily: _regularFont, fontPackage: _pkg);
const _pawPrint = IconData(0xe648, fontFamily: _regularFont, fontPackage: _pkg);
const _personSimpleHike = IconData(
  0xed54,
  fontFamily: _regularFont,
  fontPackage: _pkg,
);
const _piggyBank = IconData(
  0xea04,
  fontFamily: _regularFont,
  fontPackage: _pkg,
);
const _planet = IconData(0xe652, fontFamily: _regularFont, fontPackage: _pkg);
const _playCircle = IconData(
  0xe3d2,
  fontFamily: _regularFont,
  fontPackage: _pkg,
);
const _quotes = IconData(0xe660, fontFamily: _regularFont, fontPackage: _pkg);
const _scissors = IconData(0xeae0, fontFamily: _regularFont, fontPackage: _pkg);
const _shoppingCart = IconData(
  0xe41e,
  fontFamily: _regularFont,
  fontPackage: _pkg,
);
const _shovel = IconData(0xe9e6, fontFamily: _regularFont, fontPackage: _pkg);
const _solarPanel = IconData(
  0xed7a,
  fontFamily: _regularFont,
  fontPackage: _pkg,
);
const _sparkle = IconData(0xe6a2, fontFamily: _regularFont, fontPackage: _pkg);
const _star = IconData(0xe46a, fontFamily: _regularFont, fontPackage: _pkg);
const _tent = IconData(0xe8ba, fontFamily: _regularFont, fontPackage: _pkg);
const _toolbox = IconData(0xeca0, fontFamily: _regularFont, fontPackage: _pkg);
const _tray = IconData(0xe4aa, fontFamily: _regularFont, fontPackage: _pkg);
const _waves = IconData(0xe6de, fontFamily: _regularFont, fontPackage: _pkg);
const _wine = IconData(0xe6b2, fontFamily: _regularFont, fontPackage: _pkg);
const _wrench = IconData(0xe5d4, fontFamily: _regularFont, fontPackage: _pkg);
