/// image_library_screen.dart – Bildbibliothek: durchsuchbares Raster aller
/// Symbolbilder. Als Browser („Mehr“-Tab) oder als Bildwähler
/// (selectMode: Tippen liefert den Asset-Pfad an den Aufrufer zurück).
library;
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:fwapp/features/equipment/presentation/providers/image_library_providers.dart';

/// Öffnet die Bibliothek als Bildwähler; null bei Abbruch.
Future<String?> pickFromImageLibrary(BuildContext context) =>
    Navigator.of(context).push<String>(MaterialPageRoute(
        builder: (_) => const ImageLibraryScreen(selectMode: true)));

class ImageLibraryScreen extends ConsumerStatefulWidget {
  final bool selectMode;
  const ImageLibraryScreen({super.key, this.selectMode = false});

  @override
  ConsumerState<ImageLibraryScreen> createState() =>
      _ImageLibraryScreenState();
}

class _ImageLibraryScreenState extends ConsumerState<ImageLibraryScreen> {
  final _searchController = TextEditingController();

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final libraryAsync = ref.watch(imageLibraryProvider);

    return Scaffold(
      appBar: AppBar(
        title: Text(widget.selectMode ? 'Bild auswählen' : 'Bildbibliothek'),
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(64),
          child: Padding(
            padding: const EdgeInsets.fromLTRB(16, 4, 16, 12),
            child: TextField(
              controller: _searchController,
              autofocus: widget.selectMode,
              onChanged: (_) => setState(() {}),
              decoration: InputDecoration(
                hintText: 'Suchen … (z. B. „Schlauch“, „TS“, „Pylone“)',
                prefixIcon: const Icon(Icons.search),
                suffixIcon: _searchController.text.isEmpty
                    ? null
                    : IconButton(
                        icon: const Icon(Icons.clear),
                        onPressed: () =>
                            setState(_searchController.clear),
                      ),
                filled: true,
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(28),
                  borderSide: BorderSide.none,
                ),
                contentPadding: EdgeInsets.zero,
              ),
            ),
          ),
        ),
      ),
      body: libraryAsync.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) =>
            Center(child: Text('Bibliothek nicht ladbar: $e')),
        data: (entries) {
          final results =
              searchImageLibrary(entries, _searchController.text);
          if (results.isEmpty) {
            return const Center(
                child: Text('Kein Symbolbild gefunden –\n'
                    'andere Schreibweise probieren?',
                    textAlign: TextAlign.center));
          }
          return GridView.builder(
            padding: const EdgeInsets.all(12),
            gridDelegate: const SliverGridDelegateWithMaxCrossAxisExtent(
              maxCrossAxisExtent: 130,
              mainAxisSpacing: 10,
              crossAxisSpacing: 10,
              childAspectRatio: 0.78,
            ),
            itemCount: results.length,
            itemBuilder: (context, i) {
              final entry = results[i];
              return InkWell(
                borderRadius: BorderRadius.circular(14),
                onTap: () => widget.selectMode
                    ? Navigator.of(context).pop(entry.assetPath)
                    : _showDetail(context, entry),
                child: Column(
                  children: [
                    Expanded(
                      child: ClipRRect(
                        borderRadius: BorderRadius.circular(14),
                        child: Image.asset(entry.assetPath,
                            fit: BoxFit.contain),
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      entry.shortName ?? entry.name,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      textAlign: TextAlign.center,
                      style: const TextStyle(fontSize: 11),
                    ),
                  ],
                ),
              );
            },
          );
        },
      ),
    );
  }

  void _showDetail(BuildContext context, ImageLibraryEntry entry) {
    showDialog<void>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(entry.name),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Image.asset(entry.assetPath, width: 160, height: 160),
            const SizedBox(height: 12),
            const Text(
              'Symbolbild aus der Bildbibliothek. Echte Fotos entstehen '
              'über „Foto aufnehmen“ am Gerät und ersetzen das Symbolbild.',
              style: TextStyle(fontSize: 13),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('Schließen'),
          ),
        ],
      ),
    );
  }
}
