import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import 'package:share_plus/share_plus.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../constants.dart';
import '../../data/library_store.dart';
import '../../theme.dart';

/// A stored image from PinImages/, by filename.
class StoredImage extends StatelessWidget {
  const StoredImage(this.filename, {super.key, this.fit = BoxFit.cover});

  final String filename;
  final BoxFit fit;

  @override
  Widget build(BuildContext context) {
    final file = context.read<LibraryStore>().images.fileFor(filename);
    return Image.file(
      file,
      fit: fit,
      gaplessPlayback: true,
      errorBuilder: (context, _, _) => ColoredBox(
        color: PlinkPalette.of(context).fill,
        child: Center(
          child: Icon(
            Icons.broken_image_outlined,
            color: PlinkPalette.of(context).tertiaryLabel,
          ),
        ),
      ),
    );
  }
}

class EmptyState extends StatelessWidget {
  const EmptyState({
    super.key,
    required this.icon,
    required this.title,
    required this.subtitle,
    this.actionTitle,
    this.onAction,
  });

  final IconData icon;
  final String title;
  final String subtitle;
  final String? actionTitle;
  final VoidCallback? onAction;

  /// Laid out like SwiftUI's ContentUnavailableView.
  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final p = PlinkPalette.of(context);
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 52, color: p.secondaryLabel),
            const SizedBox(height: 14),
            Text(
              title,
              style: theme.textTheme.titleLarge?.copyWith(
                fontSize: 22,
                fontWeight: FontWeight.w700,
              ),
            ),
            const SizedBox(height: 6),
            Text(
              subtitle,
              textAlign: TextAlign.center,
              style: theme.textTheme.bodyLarge?.copyWith(
                color: p.secondaryLabel,
              ),
            ),
            if (actionTitle != null) ...[
              const SizedBox(height: 18),
              FilledButton(onPressed: onAction, child: Text(actionTitle!)),
            ],
          ],
        ),
      ),
    );
  }
}

bool isCompact(BuildContext context) =>
    MediaQuery.sizeOf(context).width < AppConstants.compactBreakpoint;

bool get isDesktop =>
    Platform.isMacOS || Platform.isLinux || Platform.isWindows;

/// Full-screen page on phones, centered dialog on wider screens.
Future<T?> showAdaptiveSheet<T>(BuildContext context, WidgetBuilder builder) {
  if (isCompact(context)) {
    return Navigator.of(context)
        .push<T>(MaterialPageRoute(fullscreenDialog: true, builder: builder));
  }
  return showDialog<T>(
    context: context,
    builder: (context) => Dialog(
      clipBehavior: Clip.antiAlias,
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 560, maxHeight: 720),
        child: builder(context),
      ),
    ),
  );
}

Future<void> openLink(BuildContext context, String url) async {
  final uri = Uri.tryParse(url);
  if (uri == null ||
      !await launchUrl(uri, mode: LaunchMode.externalApplication)) {
    if (context.mounted) showSnack(context, 'Could not open link');
  }
}

Future<void> copyLink(BuildContext context, String url) async {
  await Clipboard.setData(ClipboardData(text: url));
  if (context.mounted) showSnack(context, 'Link copied');
}

/// Share sheet where the platform has one; desktop Linux falls back to copy.
Future<void> shareLink(BuildContext context, String url, {Rect? origin}) async {
  if (Platform.isLinux) return copyLink(context, url);
  await SharePlus.instance.share(
    ShareParams(uri: Uri.parse(url), sharePositionOrigin: origin),
  );
}

void showSnack(BuildContext context, String message) {
  ScaffoldMessenger.of(context)
    ..hideCurrentSnackBar()
    ..showSnackBar(
      SnackBar(content: Text(message), behavior: SnackBarBehavior.floating),
    );
}

Rect? originRect(BuildContext context) {
  final box = context.findRenderObject() as RenderBox?;
  if (box == null || !box.hasSize) return null;
  return box.localToGlobal(Offset.zero) & box.size;
}

/// Right-click on desktop, long-press on touch.
class ContextMenuRegion extends StatelessWidget {
  const ContextMenuRegion({
    super.key,
    required this.child,
    required this.itemsBuilder,
  });

  final Widget child;
  final List<PopupMenuEntry<void>> Function(BuildContext context) itemsBuilder;

  @override
  Widget build(BuildContext context) {
    void show(Offset position) {
      showMenu<void>(
        context: context,
        position: RelativeRect.fromLTRB(
          position.dx,
          position.dy,
          position.dx,
          position.dy,
        ),
        items: itemsBuilder(context),
      );
    }

    return GestureDetector(
      onSecondaryTapDown: (d) => show(d.globalPosition),
      onLongPressStart: (d) => show(d.globalPosition),
      child: child,
    );
  }
}

/// iOS-style page: a large bold title that scrolls away, with a small
/// title fading into the bar once it's gone, and an optional [header]
/// (e.g. the search field) beneath it.
class LargeTitlePage extends StatefulWidget {
  const LargeTitlePage({
    super.key,
    required this.title,
    required this.slivers,
    this.actions = const [],
    this.header,
    this.background,
  });

  final String title;
  final List<Widget> slivers;
  final List<Widget> actions;
  final Widget? header;
  final Color? background;

  @override
  State<LargeTitlePage> createState() => _LargeTitlePageState();
}

class _LargeTitlePageState extends State<LargeTitlePage> {
  final _scroll = ScrollController();
  bool _collapsed = false;

  @override
  void initState() {
    super.initState();
    _scroll.addListener(() {
      final collapsed = _scroll.offset > 36;
      if (collapsed != _collapsed) setState(() => _collapsed = collapsed);
    });
  }

  @override
  void dispose() {
    _scroll.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final p = PlinkPalette.of(context);
    final bg = widget.background ?? p.background;
    return Scaffold(
      backgroundColor: bg,
      body: CustomScrollView(
        controller: _scroll,
        slivers: [
          SliverAppBar(
            pinned: true,
            backgroundColor: bg,
            centerTitle: true,
            title: AnimatedOpacity(
              opacity: _collapsed ? 1 : 0,
              duration: const Duration(milliseconds: 150),
              child: Text(widget.title, maxLines: 1),
            ),
            shape: Border(
              bottom: BorderSide(
                color: _collapsed ? p.separator : Colors.transparent,
                width: 0.5,
              ),
            ),
            actions: [...widget.actions, const SizedBox(width: 8)],
          ),
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(16, 0, 16, 10),
              child: Text(
                widget.title,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: Theme.of(context).textTheme.headlineMedium,
              ),
            ),
          ),
          if (widget.header != null) SliverToBoxAdapter(child: widget.header),
          ...widget.slivers,
        ],
      ),
    );
  }
}

/// The card the SwiftUI app draws: `.regularMaterial` background, 12pt
/// corners, and a soft drop shadow.
class PlinkCard extends StatelessWidget {
  const PlinkCard({super.key, required this.child, this.onTap});

  final Widget child;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final p = PlinkPalette.of(context);
    final radius = BorderRadius.circular(AppConstants.cardCornerRadius);
    return DecoratedBox(
      decoration: BoxDecoration(
        borderRadius: radius,
        boxShadow: [
          BoxShadow(
            color: p.cardShadow,
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Material(
        color: p.card,
        borderRadius: radius,
        clipBehavior: Clip.antiAlias,
        child: InkWell(onTap: onTap, child: child),
      ),
    );
  }
}

/// A SwiftUI `Form` section: small gray header, rows on a rounded inset
/// card, hairline separators between rows, optional footer.
class GroupedSection extends StatelessWidget {
  const GroupedSection({
    super.key,
    this.header,
    this.footer,
    required this.children,
  });

  final String? header;
  final String? footer;
  final List<Widget> children;

  @override
  Widget build(BuildContext context) {
    final p = PlinkPalette.of(context);
    final caption = TextStyle(fontSize: 13, color: p.secondaryLabel);
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 0, 16, 24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (header != null)
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 0, 16, 6),
              child: Text(header!.toUpperCase(), style: caption),
            ),
          ClipRRect(
            borderRadius: BorderRadius.circular(12),
            child: Material(
              color: p.groupedCell,
              child: Column(
                children: [
                  for (var i = 0; i < children.length; i++) ...[
                    if (i > 0) Divider(height: 0.5, thickness: 0.5, indent: 16),
                    children[i],
                  ],
                ],
              ),
            ),
          ),
          if (footer != null)
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 6, 16, 0),
              child: Text(footer!, style: caption),
            ),
        ],
      ),
    );
  }
}

/// One row in a [GroupedSection]: a `LabeledContent`, a navigation link
/// (with [chevron]), or a button (amber [title] via [isButton]).
class GroupedRow extends StatelessWidget {
  const GroupedRow({
    super.key,
    required this.title,
    this.icon,
    this.value,
    this.subtitle,
    this.onTap,
    this.chevron = false,
    this.isButton = false,
    this.destructive = false,
  });

  final String title;
  final IconData? icon;
  final String? value;
  final String? subtitle;
  final VoidCallback? onTap;
  final bool chevron;
  final bool isButton;
  final bool destructive;

  @override
  Widget build(BuildContext context) {
    final p = PlinkPalette.of(context);
    final tint = destructive
        ? Theme.of(context).colorScheme.error
        : (isButton ? plinkAccent : p.label);
    return InkWell(
      onTap: onTap,
      child: ConstrainedBox(
        constraints: const BoxConstraints(minHeight: 44),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
          child: Row(
            children: [
              if (icon != null) ...[
                Icon(icon, size: 20, color: destructive ? tint : plinkAccent),
                const SizedBox(width: 12),
              ],
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(title, style: TextStyle(fontSize: 17, color: tint)),
                    if (subtitle != null)
                      Padding(
                        padding: const EdgeInsets.only(top: 2),
                        child: Text(
                          subtitle!,
                          style: TextStyle(
                            fontSize: 13,
                            color: p.secondaryLabel,
                          ),
                        ),
                      ),
                  ],
                ),
              ),
              if (value != null)
                Text(
                  value!,
                  style: TextStyle(fontSize: 17, color: p.secondaryLabel),
                ),
              if (chevron)
                Padding(
                  padding: const EdgeInsets.only(left: 6),
                  child: Icon(Icons.chevron_right, color: p.tertiaryLabel),
                ),
            ],
          ),
        ),
      ),
    );
  }
}
