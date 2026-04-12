import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter_hooks/flutter_hooks.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';

import '../../core/api/elysium_api.dart';
import '../../core/models/track.dart';
import '../../core/store/providers.dart';
import '../../core/utils.dart';

const _genres = [
  'Pop', 'Hip-Hop', 'R&B', 'Rock', 'Electronic',
  'Jazz', 'Classical', 'K-Pop', 'Indie',
];

class SearchScreen extends HookConsumerWidget {
  const SearchScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final serverIp = ref.watch(serverIpProvider);
    final api = useMemoized(() => ElysiumApi(serverIp), [serverIp]);
    final cs = Theme.of(context).colorScheme;
    final isDark = Theme.of(context).brightness == Brightness.dark;

    final query = useState('');
    final results = useState<List<Map<String, dynamic>>>([]);
    final trending = useState<List<Map<String, dynamic>>>([]);
    final loading = useState(false);
    final selectedGenre = useState<String?>(null);
    final controller = useTextEditingController();

    // Load trending on mount
    useEffect(() {
      api.itunesTopSongs('us', limit: 20).then((data) {
        final entries = (data?['feed']?['entry'] as List<dynamic>? ?? []);
        trending.value = entries
            .map((e) => {
                  'id': (e['id']?['attributes']?['im:id'] ?? '').toString(),
                  'title': e['im:name']?['label'] ?? '—',
                  'artist': e['im:artist']?['label'] ?? '—',
                  'artwork': e['im:image']?[2]?['label'],
                  'url': extractItunesUrl(e['link']),
                })
            .toList()
            .cast();
      }).catchError((_) {});
      return null;
    }, [serverIp]);

    // Debounced search
    useEffect(() {
      if (query.value.trim().isEmpty) {
        results.value = [];
        return null;
      }
      final timer = Stream.fromFuture(
        Future.delayed(
          const Duration(milliseconds: 450),
          () async {
            loading.value = true;
            try {
              final data = await api.itunesSearch(query.value);
              results.value = ((data['results'] as List<dynamic>? ?? [])
                    .map((t) => {
                          'id': t['trackId']?.toString() ?? '',
                          'title': t['trackName'] ?? '—',
                          'artist': t['artistName'] ?? '—',
                          'artwork': (t['artworkUrl100'] as String?)
                              ?.replaceAll('100x100bb', '400x400bb'),
                          'url': t['previewUrl'],
                        })
                    .toList())
                  .cast();
            } finally {
              loading.value = false;
            }
          },
        ),
      ).listen((_) {});
      return timer.cancel;
    }, [query.value]);

    Future<void> searchGenre(String genre) async {
      selectedGenre.value = genre;
      query.value = '';
      controller.clear();
      loading.value = true;
      try {
        final data = await api.itunesSearch('$genre music', limit: 30);
        results.value = ((data['results'] as List<dynamic>? ?? [])
              .map((t) => {
                    'id': t['trackId']?.toString() ?? '',
                    'title': t['trackName'] ?? '—',
                    'artist': t['artistName'] ?? '—',
                    'artwork': (t['artworkUrl100'] as String?)
                        ?.replaceAll('100x100bb', '400x400bb'),
                    'url': t['previewUrl'],
                  })
              .toList())
            .cast();
      } finally {
        loading.value = false;
      }
    }

    void playResult(List<Map<String, dynamic>> source, int index) {
      final tracks = source
          .map((r) => Track(
                id: r['id'] ?? '',
                title: r['title'] ?? '—',
                artist: r['artist'] ?? '—',
                artwork: r['artwork'],
                url: r['url'] ?? '',
              ))
          .toList();
      ref.read(playerProvider.notifier).setQueue(tracks);
      ref.read(playerProvider.notifier).playIndex(index);
    }

    final isSearching =
        query.value.trim().isNotEmpty || selectedGenre.value != null;
    final displayList = isSearching ? results.value : trending.value;

    return Scaffold(
      backgroundColor: isDark ? const Color(0xFF050505) : cs.surface,
      body: SafeArea(
        bottom: false,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Header
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 20, 20, 16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Search',
                    style: TextStyle(
                      fontSize: 34,
                      fontWeight: FontWeight.w800,
                      color: isDark ? Colors.white : cs.onSurface,
                      letterSpacing: -0.5,
                    ),
                  ),
                  const SizedBox(height: 14),
                  // Search box
                  Container(
                    height: 46,
                    decoration: BoxDecoration(
                      color: cs.surfaceContainerHigh,
                      borderRadius: BorderRadius.circular(14),
                    ),
                    child: Row(
                      children: [
                        const SizedBox(width: 12),
                        Icon(Icons.search_rounded,
                            size: 20, color: cs.onSurfaceVariant),
                        const SizedBox(width: 8),
                        Expanded(
                          child: TextField(
                            controller: controller,
                            onChanged: (v) {
                              query.value = v;
                              selectedGenre.value = null;
                            },
                            style: TextStyle(
                                fontSize: 15, color: cs.onSurface),
                            decoration: InputDecoration(
                              hintText: 'Songs, artists, albums...',
                              hintStyle:
                                  TextStyle(color: cs.onSurfaceVariant),
                              border: InputBorder.none,
                              isDense: true,
                              contentPadding:
                                  const EdgeInsets.symmetric(vertical: 12),
                            ),
                          ),
                        ),
                        if (query.value.isNotEmpty)
                          IconButton(
                            icon: Icon(Icons.cancel_rounded,
                                size: 18, color: cs.onSurfaceVariant),
                            onPressed: () {
                              controller.clear();
                              query.value = '';
                              results.value = [];
                              selectedGenre.value = null;
                            },
                          ),
                      ],
                    ),
                  ),
                ],
              ),
            ),

            // Genre chips
            if (!isSearching) ...[
              Padding(
                padding: const EdgeInsets.only(left: 20, bottom: 10),
                child: Text(
                  'BROWSE BY GENRE',
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w700,
                    letterSpacing: 1,
                    color: isDark
                        ? Colors.white.withValues(alpha: 0.4)
                        : cs.onSurfaceVariant,
                  ),
                ),
              ),
              SizedBox(
                height: 38,
                child: ListView.separated(
                  scrollDirection: Axis.horizontal,
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  itemCount: _genres.length,
                  separatorBuilder: (_, __) => const SizedBox(width: 8),
                  itemBuilder: (context, i) {
                    return GestureDetector(
                      onTap: () => searchGenre(_genres[i]),
                      child: Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 16, vertical: 8),
                        decoration: BoxDecoration(
                          color: cs.primaryContainer,
                          borderRadius: BorderRadius.circular(20),
                        ),
                        child: Text(
                          _genres[i],
                          style: TextStyle(
                            color: cs.onPrimaryContainer,
                            fontWeight: FontWeight.w700,
                            fontSize: 13,
                          ),
                        ),
                      ),
                    );
                  },
                ),
              ),
              const SizedBox(height: 16),
              Padding(
                padding: const EdgeInsets.only(left: 20, bottom: 8),
                child: Text(
                  'TRENDING NOW',
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w700,
                    letterSpacing: 1,
                    color: isDark
                        ? Colors.white.withValues(alpha: 0.4)
                        : cs.onSurfaceVariant,
                  ),
                ),
              ),
            ],

            // Results list
            Expanded(
              child: loading.value
                  ? Center(
                      child:
                          CircularProgressIndicator(color: cs.primary))
                  : displayList.isEmpty && isSearching
                      ? Center(
                          child: Column(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Icon(Icons.music_off_rounded,
                                  size: 52,
                                  color: cs.onSurfaceVariant
                                      .withValues(alpha: 0.3)),
                              const SizedBox(height: 12),
                              Text(
                                'No results found',
                                style: TextStyle(
                                    color: cs.onSurfaceVariant
                                        .withValues(alpha: 0.5)),
                              ),
                            ],
                          ),
                        )
                      : ListView.builder(
                          padding: const EdgeInsets.only(bottom: 160),
                          itemCount: displayList.length,
                          itemBuilder: (context, index) {
                            final item = displayList[index];
                            return ListTile(
                              contentPadding:
                                  const EdgeInsets.symmetric(
                                      horizontal: 16, vertical: 4),
                              leading: ClipRRect(
                                borderRadius: BorderRadius.circular(8),
                                child: item['artwork'] != null
                                    ? CachedNetworkImage(
                                        imageUrl: item['artwork']!,
                                        width: 52,
                                        height: 52,
                                        fit: BoxFit.cover,
                                        errorWidget: (_, __, ___) =>
                                            _placeholder(cs),
                                      )
                                    : _placeholder(cs),
                              ),
                              title: Text(
                                item['title'] ?? '—',
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: TextStyle(
                                  fontWeight: FontWeight.w700,
                                  fontSize: 14,
                                  color: isDark
                                      ? Colors.white
                                      : cs.onSurface,
                                ),
                              ),
                              subtitle: Text(
                                item['artist'] ?? '—',
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: TextStyle(
                                    fontSize: 12,
                                    color: cs.onSurfaceVariant),
                              ),
                              trailing: Icon(
                                  Icons.play_circle_outline_rounded,
                                  color: cs.primary,
                                  size: 28),
                              onTap: () =>
                                  playResult(displayList, index),
                            );
                          },
                        ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _placeholder(ColorScheme cs) => Container(
        width: 52,
        height: 52,
        color: cs.surfaceContainerHighest,
        child: Icon(Icons.music_note_rounded,
            color: cs.primary.withValues(alpha: 0.4), size: 24),
      );
}
