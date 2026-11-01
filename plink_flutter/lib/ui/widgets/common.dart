import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import 'package:share_plus/share_plus.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../constants.dart';
import '../../data/library_store.dart';

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
      errorBuilder: (_, _, _) => const ColoredBox(
        color: Colors.black12,
        child: Center(child: Icon(Icons.broken_image_outlined)),
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

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 48, color: theme.colorScheme.onSurfaceVariant),
            const SizedBox(height: 12),
            Text(title, style: theme.textTheme.titleLarge),
            const SizedBox(height: 6),
            Text(
              subtitle,
              textAlign: TextAlign.center,
              style: theme.textTheme.bodyMedium?.copyWith(
                color: theme.colorScheme.onSurfaceVariant,
              ),
            ),
            if (actionTitle != null) ...[
              const SizedBox(height: 16),
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
