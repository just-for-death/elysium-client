import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter_hooks/flutter_hooks.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';
import 'package:shimmer/shimmer.dart';

import '../../core/api/elysium_api.dart';
import '../../core/models/track.dart';
import '../../core/store/providers.dart';
import '../../core/utils.dart';
import '../../core/widgets/glass_widgets.dart';

const _countries = [
  ('us', '🇺🇸 US'),
  ('gb', '🇬🇧 UK'),
  ('jp', '🇯🇵 Japan'),
  ('kr', '🇰🇷 Korea'),
  ('in', '🇮🇳 India'),
  ('de', '🇩🇪 Germany'),
];

class HomeScreen extends HookConsumerWidget {
  const HomeScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final serverIp = ref.watch(serverIpProvider);
    final settings = ref.watch(settingsProvider);
    final api = useMemoized(
      () => ElysiumApi(serverIp, apiSecret: settings?.apiSecret ?? ''),
      [serverIp, settings?.apiSecret],
    );
    final cs = Theme.of(context).colorScheme;
    final isDark = Theme.of(context).brightness == Brightness.dark;

    final country = useState('us');
    final trending = useState<List<Map<String, dynamic>>>([]);
    final history = useState<List<Track>>([]);
    final loading = useState(true);

    Future<void> load() async {
      loading.value = true;
      try {
        final results = await Future.wait([
          api.itunesTopSongs(country.value, limit: 20).catchError((_) => null),
          api.getHistory().catchError((_) => <Track>[]),
        ]);

        final rss = results[0] as dynamic;
        final entries = (rss?['feed']?['entry'] as List<dynamic>? ?? []);
        trending.value = entries
            .map((e) => {
                  'id': (e['id']?['attributes']?['im:id'] ?? '').toString(),
                  'title': e['im:name']?['label'] ?? '—',
                  'artist': e['im:artist']?['label'] ?? '—',
                  'artwork': e['im:image']?[2]?['label'],
                  'url': extractItunesUrl(e['link']),
                })
            .toList()
            .cast<Map<String, dynamic>>();

        history.value =
            ((results[1] as List<Track>? ?? []).take(10)).toList();
      } finally {
        loading.value = false;
      }
    }

    useEffect(() {
      load();
      return null;
    }, [serverIp, country.value]);

    return PremiumBackground(
      child: RefreshIndicator(
        onRefresh: load,
        color: cs.primary,
        backgroundColor: Colors.white,
        child: CustomScrollView(
          physics: const BouncingScrollPhysics(),
          slivers: [
            // Large title header
            SliverToBoxAdapter(
              child: SafeArea(
                bottom: false,
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(24, 32, 24, 12),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      ShaderMask(
                        shaderCallback: (bounds) => LinearGradient(
                          colors: [Colors.white, Colors.white.withValues(alpha: 0.7)],
                        ).createShader(bounds),
                        child: Text(
                          'Elysium',
                          style: TextStyle(
                            fontSize: 48,
                            fontWeight: FontWeight.w900,
                            color: Colors.white,
                            letterSpacing: -2,
                            height: 1,
                          ),
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        'Your music ecosystem, perfected.',
                        style: TextStyle(
                          fontSize: 15,
                          fontWeight: FontWeight.w500,
                          color: Colors.white.withValues(alpha: 0.4),
                          letterSpacing: 0.2,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),

            // Country picker
            SliverToBoxAdapter(
              child: Container(
                height: 48,
                margin: const EdgeInsets.only(top: 8),
                child: ListView.separated(
                  scrollDirection: Axis.horizontal,
                  padding: const EdgeInsets.symmetric(horizontal: 24),
                  itemCount: _countries.length,
                  separatorBuilder: (_, __) => const SizedBox(width: 10),
                  itemBuilder: (context, i) {
                    final (cc, label) = _countries[i];
                    return GlassPill(
                      label: label,
                      selected: country.value == cc,
                      onTap: () => country.value = cc,
                    );
                  },
                ),
              ),
            ),

            const SliverToBoxAdapter(child: SizedBox(height: 32)),

            // Trending section
            SliverToBoxAdapter(
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 24),
                child: Row(
                  children: [
                    Text(
                      'Trending Now',
                      style: TextStyle(
                        fontSize: 22,
                        fontWeight: FontWeight.w800,
                        color: Colors.white,
                        letterSpacing: -0.5,
                      ),
                    ),
                    const Spacer(),
                    Icon(Icons.trending_up_rounded, color: cs.primary, size: 20),
                  ],
                ),
              ),
            ),
            const SliverToBoxAdapter(child: SizedBox(height: 16)),

            SliverToBoxAdapter(
              child: loading.value
                  ? _TrendingShimmer(isDark: isDark)
                  : trending.value.isEmpty
                      ? _EmptyTrending(cs: cs)
                      : _TrendingRow(
                          items: trending.value,
                          cs: cs,
                          isDark: isDark,
                          onTap: (idx) {
                            final tracks = trending.value
                                .map((t) => Track(
                                      id: t['id'] ?? '',
                                      title: t['title'] ?? '—',
                                      artist: t['artist'] ?? '—',
                                      artwork: t['artwork'],
                                      url: t['url'] ?? '',
                                    ))
                                .toList();
                            ref
                                .read(playerProvider.notifier)
                                .setQueue(tracks);
                            ref
                                .read(playerProvider.notifier)
                                .playIndex(idx);
                            if (serverIp.isNotEmpty) {
                              api
                                  .addHistory(tracks[idx])
                                  .catchError((_) {});
                            }
                          },
                        ),
            ),

            // Recently Played
            if (history.value.isNotEmpty) ...[
              const SliverToBoxAdapter(child: SizedBox(height: 36)),
              SliverToBoxAdapter(
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 24),
                  child: Text(
                    'Recently Played',
                    style: TextStyle(
                      fontSize: 22,
                      fontWeight: FontWeight.w800,
                      color: Colors.white,
                      letterSpacing: -0.5,
                    ),
                  ),
                ),
              ),
              const SliverToBoxAdapter(child: SizedBox(height: 16)),
              SliverList(
                delegate: SliverChildBuilderDelegate(
                  (context, index) {
                    final track = history.value[index];
                    return Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 4),
                      child: GlassCard(
                        padding: EdgeInsets.zero,
                        borderRadius: BorderRadius.circular(16),
                        opacity: 0.04,
                        child: _HistoryTile(
                          track: track,
                          cs: cs,
                          isDark: isDark,
                          onTap: () {
                            ref.read(playerProvider.notifier).setQueue(
                                  history.value.sublist(index),
                                );
                            ref.read(playerProvider.notifier).playIndex(0);
                          },
                        ),
                      ),
                    );
                  },
                  childCount: history.value.length,
                ),
              ),
            ],

            const SliverToBoxAdapter(child: SizedBox(height: 160)),
          ],
        ),
      ),
    );
  }
}

class _TrendingRow extends StatelessWidget {
  const _TrendingRow({
    required this.items,
    required this.cs,
    required this.isDark,
    required this.onTap,
  });
  final List<Map<String, dynamic>> items;
  final ColorScheme cs;
  final bool isDark;
  final void Function(int) onTap;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 230,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: 20),
        itemCount: items.length,
        separatorBuilder: (_, __) => const SizedBox(width: 16),
        itemBuilder: (context, i) {
          final item = items[i];
          return GestureDetector(
            onTap: () => onTap(i),
            child: GlassCard(
              padding: const EdgeInsets.all(10),
              opacity: 0.1,
              borderRadius: BorderRadius.circular(20),
              child: SizedBox(
                width: 150,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    ClipRRect(
                      borderRadius: BorderRadius.circular(12),
                      child: item['artwork'] != null
                          ? CachedNetworkImage(
                              imageUrl: item['artwork']!,
                              width: 150,
                              height: 150,
                              fit: BoxFit.cover,
                              errorWidget: (_, __, ___) => _artPlaceholder(cs),
                            )
                          : _artPlaceholder(cs),
                    ),
                    const SizedBox(height: 10),
                    Text(
                      item['title'] ?? '—',
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        color: Colors.white,
                        fontWeight: FontWeight.w800,
                        fontSize: 14,
                        letterSpacing: -0.2,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      item['artist'] ?? '—',
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        color: Colors.white.withValues(alpha: 0.5),
                        fontSize: 12,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          );
        },
      ),
    );
  }

  Widget _artPlaceholder(ColorScheme cs) => Container(
        width: 140,
        height: 140,
        color: cs.surfaceContainerHighest,
        child: Icon(Icons.music_note_rounded,
            color: cs.primary.withValues(alpha: 0.4), size: 40),
      );
}

class _HistoryTile extends StatelessWidget {
  const _HistoryTile({
    required this.track,
    required this.cs,
    required this.isDark,
    required this.onTap,
  });
  final Track track;
  final ColorScheme cs;
  final bool isDark;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
        child: Row(
          children: [
            ClipRRect(
              borderRadius: BorderRadius.circular(8),
              child: track.artwork != null
                  ? CachedNetworkImage(
                      imageUrl: track.artwork!,
                      width: 50,
                      height: 50,
                      fit: BoxFit.cover,
                      errorWidget: (_, __, ___) => _placeholder(cs),
                    )
                  : _placeholder(cs),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    track.title,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      fontWeight: FontWeight.w700,
                      fontSize: 14,
                      color: isDark ? Colors.white : cs.onSurface,
                    ),
                  ),
                  Text(
                    track.artist,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      fontSize: 12,
                      color: isDark
                          ? Colors.white.withValues(alpha: 0.5)
                          : cs.onSurfaceVariant,
                    ),
                  ),
                ],
              ),
            ),
            Icon(Icons.play_circle_outline_rounded,
                size: 28, color: cs.primary),
          ],
        ),
      ),
    );
  }

  Widget _placeholder(ColorScheme cs) => Container(
        width: 50,
        height: 50,
        color: cs.surfaceContainerHighest,
        child: Icon(Icons.music_note_rounded,
            color: cs.primary.withValues(alpha: 0.4), size: 22),
      );
}

class _TrendingShimmer extends StatelessWidget {
  const _TrendingShimmer({required this.isDark});
  final bool isDark;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 200,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: 16),
        itemCount: 6,
        separatorBuilder: (_, __) => const SizedBox(width: 12),
        itemBuilder: (_, __) => Shimmer.fromColors(
          baseColor:
              isDark ? const Color(0xFF1E1E1E) : const Color(0xFFE0E0E0),
          highlightColor:
              isDark ? const Color(0xFF2A2A2A) : const Color(0xFFEEEEEE),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                width: 140,
                height: 140,
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(14),
                ),
              ),
              const SizedBox(height: 8),
              Container(
                  width: 120, height: 12, color: Colors.white),
              const SizedBox(height: 4),
              Container(width: 80, height: 10, color: Colors.white),
            ],
          ),
        ),
      ),
    );
  }
}

class _EmptyTrending extends StatelessWidget {
  const _EmptyTrending({required this.cs});
  final ColorScheme cs;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.all(32),
      child: Column(
        children: [
          Icon(Icons.wifi_off_rounded,
              size: 40, color: cs.onSurfaceVariant.withValues(alpha: 0.4)),
          const SizedBox(height: 12),
          Text(
            'Could not load trending.\nIs the server running?',
            textAlign: TextAlign.center,
            style: TextStyle(
                color: cs.onSurfaceVariant.withValues(alpha: 0.6)),
          ),
        ],
      ),
    );
  }
}
