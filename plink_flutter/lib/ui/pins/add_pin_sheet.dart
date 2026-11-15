import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';

import '../../constants.dart';
import '../../data/library_store.dart';
import '../../models/board.dart';
import '../../models/pin.dart';
import '../../services/metadata_service.dart';
import '../widgets/board_glyph.dart';

class AddPinSheet extends StatefulWidget {
  const AddPinSheet({super.key, this.board});

  final Board? board;

  @override
  State<AddPinSheet> createState() => _AddPinSheetState();
}

class _AddPinSheetState extends State<AddPinSheet> {
  final _urlController = TextEditingController();
  Timer? _debounce;
  bool _fetching = false;
  PinMetadata? _metadata;
  int? _selectedImage;
  String _lastFetched = '';
  bool _saving = false;

  @override
  void initState() {
    super.initState();
    _pasteFromClipboard();
  }

  @override
  void dispose() {
    _debounce?.cancel();
    _urlController.dispose();
    super.dispose();
  }

  Future<void> _pasteFromClipboard() async {
    final data = await Clipboard.getData(Clipboard.kTextPlain);
    final text = data?.text?.trim();
    if (text != null &&
        text.normalizedUrlString.isValidUrl &&
        _urlController.text.isEmpty) {
      _urlController.text = text;
      _fetchPreview();
    }
  }

  void _onChanged(String text) {
    _debounce?.cancel();
    final normalized = text.normalizedUrlString;
    if (!normalized.isValidUrl || normalized == _lastFetched) return;
    // Pasted full URLs fetch quickly; typing waits for a pause.
    final delay = Duration(milliseconds: text.contains('://') ? 200 : 800);
    _debounce = Timer(delay, _fetchPreview);
  }

  Future<void> _fetchPreview() async {
    final normalized = _urlController.text.normalizedUrlString;
    if (!normalized.isValidUrl || normalized == _lastFetched) return;
    final url = Uri.parse(normalized);
    _lastFetched = normalized;
    setState(() => _fetching = true);
    final store = context.read<LibraryStore>();
    PinMetadata metadata;
    try {
      metadata = await store.metadata.fetchMetadata(url);
    } catch (_) {
      // Preview failed; the user can still save without one.
      metadata = PinMetadata(domain: url.displayDomain);
    }
    if (!mounted || _lastFetched != normalized) return;
    setState(() {
      _metadata = metadata;
      _selectedImage = null;
      _fetching = false;
    });
  }

  Future<void> _save() async {
    final normalized = _urlController.text.normalizedUrlString;
    if (!normalized.isValidUrl) {
      showDialog<void>(
        context: context,
        builder: (context) => AlertDialog(
          title: const Text('Invalid URL'),
          content: const Text('Please enter a valid web URL.'),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('OK'),
            ),
          ],
        ),
      );
      return;
    }
    setState(() => _saving = true);
    final store = context.read<LibraryStore>();
    final meta = _metadata;
    final pin = Pin(
      urlString: normalized,
      title: meta?.title ?? '',
      pageDescription: meta?.description ?? '',
      domain: meta?.domain ?? Uri.parse(normalized).displayDomain,
      boardIds: [?widget.board?.id],
      sortOrder: widget.board == null ? 0 : store.pinsIn(widget.board!).length,
    );

    if (meta != null) {
      if (meta.faviconData != null) {
        pin.faviconPath = await store.images.saveFavicon(
          meta.faviconData!,
          pin.id,
        );
      }
      pin.metadataFetched = true;
    }
    store.addPin(pin);

    final selected = _selectedImage;
    if (meta != null &&
        selected != null &&
        selected < meta.availableImageUrls.length) {
      final data = await store.metadata.downloadImage(
        meta.availableImageUrls[selected],
      );
      if (data != null) await store.setImage(pin, data, custom: true);
    } else if (meta?.imageData != null) {
      await store.setImage(pin, meta!.imageData!, custom: false);
    }
    if (mounted) Navigator.of(context).pop();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final meta = _metadata;
    final canSave =
        _urlController.text.trim().isNotEmpty && !_fetching && !_saving;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Add Link'),
        centerTitle: true,
        leadingWidth: 90,
        leading: TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: const Text('Cancel'),
        ),
        actions: [
          Padding(
            padding: const EdgeInsets.only(right: 8),
            child: _saving
                ? const Padding(
                    padding: EdgeInsets.all(12),
                    child: SizedBox.square(
                      dimension: 18,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    ),
                  )
                : TextButton(
                    onPressed: canSave ? _save : null,
                    child: const Text(
                      'Save',
                      style: TextStyle(fontWeight: FontWeight.w600),
                    ),
                  ),
          ),
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          TextField(
            controller: _urlController,
            autofocus: true,
            keyboardType: TextInputType.url,
            autocorrect: false,
            enabled: !_saving,
            decoration: InputDecoration(
              labelText: 'URL',
              hintText: 'https://example.com',
              border: const OutlineInputBorder(),
              helperText: meta == null && !_fetching
                  ? 'Paste or type a web link. A preview will load automatically.'
                  : null,
              suffixIcon: _fetching
                  ? const Padding(
                      padding: EdgeInsets.all(12),
                      child: SizedBox.square(
                        dimension: 20,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      ),
                    )
                  : null,
            ),
            onChanged: (v) {
              setState(() {});
              _onChanged(v);
            },
            onSubmitted: (_) => _fetchPreview(),
          ),
          if (meta != null && meta.title.isNotEmpty) ...[
            const SizedBox(height: 20),
            Text('Preview', style: theme.textTheme.labelLarge),
            const SizedBox(height: 6),
            Text(meta.title, style: theme.textTheme.titleMedium),
            Text(
              meta.domain,
              style: theme.textTheme.bodySmall?.copyWith(
                color: theme.colorScheme.onSurfaceVariant,
              ),
            ),
          ],
          if (meta != null && meta.availableImageUrls.isNotEmpty) ...[
            const SizedBox(height: 20),
            Text(
              'Choose an Image (${meta.availableImageUrls.length} found)',
              style: theme.textTheme.labelLarge,
            ),
            const SizedBox(height: 8),
            SizedBox(
              height: 108,
              child: ListView.separated(
                scrollDirection: Axis.horizontal,
                itemCount: meta.availableImageUrls.length,
                separatorBuilder: (_, _) => const SizedBox(width: 10),
                itemBuilder: (context, i) => _ImageOption(
                  url: meta.availableImageUrls[i],
                  selected: _selectedImage == i,
                  onTap: () => setState(
                    () => _selectedImage = _selectedImage == i ? null : i,
                  ),
                ),
              ),
            ),
            const SizedBox(height: 6),
            Text(
              'Tap to select, tap again to deselect. If none is selected, the default image will be used.',
              style: theme.textTheme.bodySmall?.copyWith(
                color: theme.colorScheme.onSurfaceVariant,
              ),
            ),
          ],
          if (widget.board != null) ...[
            const SizedBox(height: 20),
            Text('Board', style: theme.textTheme.labelLarge),
            ListTile(
              contentPadding: EdgeInsets.zero,
              leading: BoardGlyph(widget.board!.boardIcon),
              title: Text(widget.board!.name),
            ),
          ],
        ],
      ),
    );
  }
}

class _ImageOption extends StatelessWidget {
  const _ImageOption({
    required this.url,
    required this.selected,
    required this.onTap,
  });

  final Uri url;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final color = Theme.of(context).colorScheme.primary;
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: 100,
        height: 100,
        margin: const EdgeInsets.all(4),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(8),
          border: Border.all(
            color: selected ? color : Colors.transparent,
            width: 3,
          ),
        ),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(5),
          child: Stack(
            fit: StackFit.expand,
            children: [
              Image.network(
                url.toString(),
                fit: BoxFit.cover,
                loadingBuilder: (_, child, progress) => progress == null
                    ? child
                    : const Center(
                        child: SizedBox.square(
                          dimension: 20,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        ),
                      ),
                errorBuilder: (_, _, _) => const ColoredBox(
                  color: Colors.black12,
                  child: Icon(Icons.warning_amber_outlined),
                ),
              ),
              if (selected)
                Positioned(
                  top: 4,
                  right: 4,
                  child: Icon(Icons.check_circle, color: color),
                ),
            ],
          ),
        ),
      ),
    );
  }
}
