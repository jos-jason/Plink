import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';

import '../../models/board_icons.dart';

/// Draws a board icon, whether it's a font icon or one of Plink's own SVG
/// glyphs, at [size] in [color] (the surrounding icon colour by default).
class BoardGlyph extends StatelessWidget {
  const BoardGlyph(this.icon, {super.key, this.size, this.color});

  final BoardIcon icon;
  final double? size;
  final Color? color;

  @override
  Widget build(BuildContext context) {
    final theme = IconTheme.of(context);
    final s = size ?? theme.size ?? 24;
    final c = color ?? theme.color ?? const Color(0xFF000000);
    final svg = icon.svg;
    if (svg == null) return Icon(icon.icon, size: s, color: c);
    return SizedBox.square(
      dimension: s,
      child: SvgPicture.string(
        svg,
        width: s,
        height: s,
        colorFilter: ColorFilter.mode(c, BlendMode.srcIn),
      ),
    );
  }
}
