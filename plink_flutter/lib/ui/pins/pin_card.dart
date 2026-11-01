import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../constants.dart';
import '../../data/library_store.dart';
import '../../models/pin.dart';
import '../widgets/common.dart';

class PinCard extends StatefulWidget {
  const PinCard({super.key, required this.pin, required this.onTap});

  final Pin pin;
  final VoidCallback onTap;

  @override
  State<PinCard> createState() => _PinCardState();
}

class _PinCardState extends State<PinCard> {
  @override
  void initState() {
    super.initState();
    _fetchIfNeeded();
  }

  @override
  void didUpdateWidget(PinCard oldWidget) {
    super.didUpdateWidget(oldWidget);
    _fetchIfNeeded();
  }

  void _fetchIfNeeded() {
    if (!widget.pin.metadataFetched) {
      // Cards fetch lazily as they scroll into view, like the Swift app.
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) context.read<LibraryStore>().ensureMetadata(widget.pin);
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final pin = widget.pin;
    final theme = Theme.of(context);
    final placeholderColor = theme.colorScheme.surfaceContainerHighest;

    Widget? media;
    if (pin.imagePath != null) {
      media = AspectRatio(
        aspectRatio: pin.imageAspectRatio.clamp(0.4, 3.0),
        child: StoredImage(pin.imagePath!),
      );
    } else if (pin.faviconPath != null) {
      media = AspectRatio(
        aspectRatio: 1.5,
        child: ColoredBox(
          color: placeholderColor,
          child: Center(
            child: ClipRRect(
              borderRadius: BorderRadius.circular(8),
              child: SizedBox.square(
                dimension: 48,
                child: StoredImage(pin.faviconPath!, fit: BoxFit.contain),
              ),
            ),
          ),
        ),
      );
    } else if (!pin.metadataFetched) {
      media = AspectRatio(
        aspectRatio: 1.5,
        child: ColoredBox(
          color: placeholderColor,
          child: const Center(
            child: SizedBox.square(
              dimension: 24,
              child: CircularProgressIndicator(strokeWidth: 2),
            ),
          ),
        ),
      );
    }

    return Card(
      margin: EdgeInsets.zero,
      clipBehavior: Clip.antiAlias,
      elevation: 1,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(AppConstants.cardCornerRadius),
      ),
      child: InkWell(
        onTap: widget.onTap,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            ?media,
            Padding(
              padding: const EdgeInsets.all(AppConstants.cardPadding),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  if (pin.title.isNotEmpty)
                    Text(
                      pin.title,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: theme.textTheme.titleSmall,
                    ),
                  if (pin.domain.isNotEmpty)
                    Padding(
                      padding: const EdgeInsets.only(top: 4),
                      child: Text(
                        pin.domain,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: theme.textTheme.bodySmall?.copyWith(
                          color: theme.colorScheme.onSurfaceVariant,
                        ),
                      ),
                    ),
                  if (pin.title.isEmpty && pin.domain.isEmpty)
                    Text(
                      pin.urlString,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: theme.textTheme.bodySmall,
                    ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
