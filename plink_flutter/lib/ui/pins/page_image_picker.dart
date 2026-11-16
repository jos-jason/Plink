import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../data/library_store.dart';
import '../../models/pin.dart';
import '../../theme.dart';
import '../widgets/common.dart';
import '../widgets/page_image_option.dart';

/// Lets the user pick a pin's image from the photos on its web page.
Future<void> showPageImagePicker(BuildContext context, Pin pin) =>
    showAdaptiveSheet(context, (_) => _PageImagePicker(pin: pin));

class _PageImagePicker extends StatefulWidget {
  const _PageImagePicker({required this.pin});

  final Pin pin;

  @override
  State<_PageImagePicker> createState() => _PageImagePickerState();
}

class _PageImagePickerState extends State<_PageImagePicker> {
  late final Future<List<Uri>> _images = _load();
  int? _saving;

  Future<List<Uri>> _load() async {
    final url = widget.pin.url;
    if (url == null) return const [];
    final meta = await context.read<LibraryStore>().metadata.fetchMetadata(url);
    return meta.availableImageUrls;
  }

  Future<void> _choose(List<Uri> images, int index) async {
    setState(() => _saving = index);
    final store = context.read<LibraryStore>();
    final data = await store.metadata.downloadImage(images[index]);
    final ok =
        data != null && await store.setImage(widget.pin, data, custom: true);
    if (!mounted) return;
    if (ok) {
      Navigator.of(context).pop();
    } else {
      setState(() => _saving = null);
      showSnack(context, 'That image couldn’t be downloaded. Try another.');
    }
  }

  @override
  Widget build(BuildContext context) {
    final p = PlinkPalette.of(context);
    return Scaffold(
      appBar: AppBar(
        title: const Text('Choose Image'),
        centerTitle: true,
        leadingWidth: 90,
        leading: TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: const Text('Cancel'),
        ),
      ),
      body: FutureBuilder<List<Uri>>(
        future: _images,
        builder: (context, snap) {
          if (snap.connectionState != ConnectionState.done) {
            return const Center(child: CircularProgressIndicator());
          }
          final images = snap.data ?? const <Uri>[];
          if (snap.hasError || images.isEmpty) {
            return EmptyState(
              icon: Icons.image_not_supported_outlined,
              title: 'No Images Found',
              subtitle: snap.hasError
                  ? 'The page couldn’t be loaded.'
                  : 'This page has no images Plink can use.',
            );
          }
          return Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 12, 16, 4),
                child: Text(
                  '${images.length} found on ${widget.pin.domain}. '
                  'Tap one to use it.',
                  style: TextStyle(color: p.secondaryLabel),
                ),
              ),
              Expanded(
                child: GridView.builder(
                  padding: const EdgeInsets.all(12),
                  gridDelegate: const SliverGridDelegateWithMaxCrossAxisExtent(
                    maxCrossAxisExtent: 120,
                  ),
                  itemCount: images.length,
                  itemBuilder: (context, i) => Stack(
                    fit: StackFit.expand,
                    children: [
                      PageImageOption(
                        url: images[i],
                        selected: _saving == i,
                        onTap: _saving == null
                            ? () => _choose(images, i)
                            : () {},
                      ),
                      if (_saving == i)
                        const Center(child: CircularProgressIndicator()),
                    ],
                  ),
                ),
              ),
            ],
          );
        },
      ),
    );
  }
}
