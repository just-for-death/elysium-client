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

const _lbRanges = [
  ('week', 'Week'),
  ('month', 'Month'),
  ('year', 'Year'),
  ('all_time', 'All time'),
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

    // ── Core state ────────────────────────────────────────────────────────────
    final country     = useState('us');
    final trending    = useState<List<Map<String, dynamic>>>([]);
    final history     = useState<List<Track>>([]);
    final favorites   = useState<List<Track>>([]);
    final lbRecent    = useState<List<dynamic>>([]);
    final lbTop       = useState<List<dynamic>>([]);
    final lbRange     = useState('month');
    final loading     = useState(true);
    final lbTopLoading = useState(false);

    // ── LB availability guard ─────────────────────────────────────────────────
    final lbEnabled = (settings?.listenBrainzEnabled ?? false) &&
        (settings?.listenBrainzUsername.isNotEmpty ?? false) &&
        (settings?.listenBrainzToken.isNotEmpty ?? false);
    final lbUsername = settings?.listenBrainzUsername ?? '';
    final lbToken    = settings?.listenBrainzToken ?? '';

    // ── Main load: trending + history + favorites + LB recent ─────────────────
    Future<void> load() async {
      loading.value = true;
      try {
        final results = await Future.wait([
          api.itunesTopSongs(country.value, limit: 20).catchError((_) => null),
          api.getHistory().catchError((_) => <Track>[]),
          api.getFavorites().catchError((_) => <Track>[]),
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

        history.value   = ((results[1] as List<Track>? ?? []).take(10)).toList();
        favorites.value = ((results[2] as List<Track>? ?? []).take(12)).toList();

        // ListenBrainz recent listens (only if configured)
        if (lbEnabled) {
          lbRecent.value = await api
              .getLBRecentListens(lbUsername, lbToken)
              .catchError((_) => <dynamic>[]);
        }
      } finally {
        loading.value = false;
      }
    }

    // ── LB top tracks: re-fetched when range or serverIp changes ──────────────
    Future<void> loadLbTop() async {
      if (!lbEnabled) return;
      lbTopLoading.value = true;
      try {
        lbTop.value = await api
            .getLBTopRecordings(lbUsername, lbToken, lbRange.value)
            .catchError((_) => <dynamic>[]);
      } finally {
        lbTopLoading.value = false;
      }
    }

    useEffect(() {
      load();
      return null;
    }, [serverIp, country.value, lbEnabled]);

    // Re-run LB top whenever range, serverIp, or LB config changes
    useEffect(() {
      loadLbTop();
      return null;
    }, [serverIp, lbRange.value, lbEnabled, lbUsername]);

    return PremiumBackground(
      child: RefreshIndicator(
        onRefresh: () async {
          await Future.wait([load(), loadLbTop()]);
        },
        color: cs.primary,
        backgroundColor: Colors.white,
        child: CustomScrollView(
          physics: const BouncingScrollPhysics(),
          slivers: [
            // ── Header ────────────────────────────────────────────────────────
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
                          colors: [
                            Colors.white,
                            Colors.white.withValues(alpha: 0.7)
                          ],
                        ).createShader(bounds),
                        child: const Text(
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

            // ── Country picker ────────────────────────────────────────────────
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

            // ── Trending Now ──────────────────────────────────────────────────
            SliverToBoxAdapter(
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 24),
                child: Row(
                  children: [
                    const Text(
                      'Trending Now',
                      style: TextStyle(
                        fontSize: 22,
                        fontWeight: FontWeight.w800,
                        color: Colors.white,
                        letterSpacing: -0.5,
                      ),
                    ),
                    const Spacer(),
                    Icon(Icons.trending_up_rounded,
                        color: cs.primary, size: 20),
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

            // ── Recently Played ───────────────────────────────────────────────
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
                      padding: const EdgeInsets.symmetric(
                          horizontal: 20, vertical: 4),
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
                            ref
                                .read(playerProvider.notifier)
                                .playIndex(0);
                          },
                        ),
                      ),
                    );
                  },
                  childCount: history.value.length,
                ),
              ),
            ],

            // ── Recent Favorites ──────────────────────────────────────────────
            if (favorites.value.isNotEmpty) ...[
              const SliverToBoxAdapter(child: SizedBox(height: 36)),
              SliverToBoxAdapter(
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 24),
                  child: Row(
                    children: [
                      Text(
                        'Recent Favorites',
                        style: TextStyle(
                          fontSize: 22,
                          fontWeight: FontWeight.w800,
                          color: Colors.white,
                          letterSpacing: -0.5,
                        ),
                      ),
                      const Spacer(),
                      Icon(Icons.favorite_rounded,
                          color: cs.primary, size: 20),
                    ],
                  ),
                ),
              ),
              const SliverToBoxAdapter(child: SizedBox(height: 16)),
              SliverToBoxAdapter(
                child: _FavoritesRow(
                  favorites: favorites.value,
                  cs: cs,
                  isDark: isDark,
                  onTap: (idx) {
                    ref
                        .read(playerProvider.notifier)
                        .setQueue(favorites.value.sublist(idx));
                    ref.read(playerProvider.notifier).playIndex(0);
                  },
                ),
              ),
            ],

            // ── Recently Listened (ListenBrainz) ──────────────────────────────
            if (lbEnabled && lbRecent.value.isNotEmpty) ...[
              const SliverToBoxAdapter(child: SizedBox(height: 36)),
              SliverToBoxAdapter(
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 24),
                  child: Row(
                    children: [
                      Text(
                        'Recently Listened',
                        style: TextStyle(
                          fontSize: 22,
                          fontWeight: FontWeight.w800,
                          color: Colors.white,
                          letterSpacing: -0.5,
                        ),
                      ),
                      const Spacer(),
                      const _LbLogo(),
                    ],
                  ),
                ),
              ),
              const SliverToBoxAdapter(child: SizedBox(height: 16)),
              SliverList(
                delegate: SliverChildBuilderDelegate(
                  (context, index) {
                    final listen = lbRecent.value[index] as Map;
                    final meta   = listen['track_metadata'] as Map? ?? {};
            final mbidMapping = meta['mbid_mapping'] as Map?;
            final caaMbid = mbidMapping?['caa_release_mbid'] as String?;
                    final listenedAt = listen['listened_at'] as int?;
                    final date = listenedAt != null
                        ? _fmtDate(
                            DateTime.fromMillisecondsSinceEpoch(
                                listenedAt * 1000))
                        : null;

                    return Padding(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 20, vertical: 4),
                      child: GlassCard(
                        padding: EdgeInsets.zero,
                        borderRadius: BorderRadius.circular(16),
                        opacity: 0.04,
                        child: _LBTrackTile(
                          title:  meta['track_name']?.toString() ?? '—',
                          artist: meta['artist_name']?.toString() ?? '—',
                          caaMbid: caaMbid,
                          cs: cs,
                          isDark: isDark,
                          right: date != null
                              ? Text(
                                  date,
                                  style: TextStyle(
                                    fontSize: 11,
                                    color: Colors.white
                                        .withValues(alpha: 0.4),
                                  ),
                                )
                              : null,
                          onTap: () {
                            final t = Track(
                              id: meta['track_name']?.toString() ?? '',
                              title: meta['track_name']?.toString() ?? '—',
                              artist: meta['artist_name']?.toString() ?? '—',
                            );
                            ref
                                .read(playerProvider.notifier)
                                .playTrackNow(t);
                          },
                        ),
                      ),
                    );
                  },
                  childCount: lbRecent.value.length,
                ),
              ),
            ],

            // ── My Top Tracks (ListenBrainz) ──────────────────────────────────
            if (lbEnabled) ...[
              const SliverToBoxAdapter(child: SizedBox(height: 36)),
              SliverToBoxAdapter(
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 24),
                  child: Row(
                    children: [
                      Text(
                        'My Top Tracks',
                        style: TextStyle(
                          fontSize: 22,
                          fontWeight: FontWeight.w800,
                          color: Colors.white,
                          letterSpacing: -0.5,
                        ),
                      ),
                      const Spacer(),
                      const _LbLogo(),
                    ],
                  ),
                ),
              ),
              const SliverToBoxAdapter(child: SizedBox(height: 12)),
              // Range chips
              SliverToBoxAdapter(
                child: _RangePills(
                  current: lbRange.value,
                  onChanged: (r) => lbRange.value = r,
                ),
              ),
              const SliverToBoxAdapter(child: SizedBox(height: 12)),
              if (lbTopLoading.value)
                SliverToBoxAdapter(
                  child: _LBListShimmer(isDark: isDark),
                )
              else if (lbTop.value.isEmpty)
                SliverToBoxAdapter(
                  child: Padding(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 24, vertical: 24),
                    child: Text(
                      'No stats yet for this period.',
                      style: TextStyle(
                        color: Colors.white.withValues(alpha: 0.4),
                        fontSize: 14,
                      ),
                    ),
                  ),
                )
              else
                SliverList(
                  delegate: SliverChildBuilderDelegate(
                    (context, index) {
                      final rec = lbTop.value[index] as Map;
                      final listenCount =
                          (rec['listen_count'] as num?)?.toInt() ?? 0;
                      final caaMbid =
                          rec['caa_release_mbid'] as String?;

                      return Padding(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 20, vertical: 4),
                        child: GlassCard(
                          padding: EdgeInsets.zero,
                          borderRadius: BorderRadius.circular(16),
                          opacity: 0.04,
                          child: _LBTrackTile(
                            title:   rec['track_name']?.toString() ?? '—',
                            artist:  rec['artist_name']?.toString() ?? '—',
                            caaMbid: caaMbid,
                            cs: cs,
                            isDark: isDark,
                            rank: index + 1,
                            right: _PlayCountBadge(
                              count: listenCount,
                              cs: cs,
                            ),
                            onTap: () {
                              final t = Track(
                                id: rec['track_name']?.toString() ?? '',
                                title:  rec['track_name']?.toString() ?? '—',
                                artist: rec['artist_name']?.toString() ?? '—',
                              );
                              ref
                                  .read(playerProvider.notifier)
                                  .playTrackNow(t);
                            },
                          ),
                        ),
                      );
                    },
                    childCount: lbTop.value.length,
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

// ── Helpers ──────────────────────────────────────────────────────────────────

String _fmtDate(DateTime dt) {
  final now = DateTime.now();
  final diff = now.difference(dt);
  if (diff.inDays == 0) return 'Today';
  if (diff.inDays == 1) return 'Yesterday';
  if (diff.inDays < 7) return '${diff.inDays}d ago';
  return '${dt.day}/${dt.month}';
}

String? _caaUrl(String? mbid) =>
    mbid != null && mbid.isNotEmpty
        ? 'https://coverartarchive.org/release/$mbid/front-250'
        : null;

// ── ListenBrainz logo badge ───────────────────────────────────────────────────

class _LbLogo extends StatelessWidget {
  const _LbLogo();

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: const Color(0xFFEB743B).withValues(alpha: 0.2),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(
          color: const Color(0xFFEB743B).withValues(alpha: 0.5),
          width: 1,
        ),
      ),
      child: const Text(
        'ListenBrainz',
        style: TextStyle(
          color: Color(0xFFEB743B),
          fontSize: 11,
          fontWeight: FontWeight.w700,
          letterSpacing: 0.3,
        ),
      ),
    );
  }
}

// ── Range pills ───────────────────────────────────────────────────────────────

class _RangePills extends StatelessWidget {
  const _RangePills({required this.current, required this.onChanged});
  final String current;
  final ValueChanged<String> onChanged;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 38,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: 24),
        itemCount: _lbRanges.length,
        separatorBuilder: (_, __) => const SizedBox(width: 10),
        itemBuilder: (_, i) {
          final (value, label) = _lbRanges[i];
          return GlassPill(
            label: label,
            selected: current == value,
            onTap: () => onChanged(value),
          );
        },
      ),
    );
  }
}

// ── Cover Art Archive artwork ─────────────────────────────────────────────────

class _CaaArtwork extends StatelessWidget {
  const _CaaArtwork({
    required this.mbid,
    required this.cs,
    required this.size,
  });
  final String? mbid;
  final ColorScheme cs;
  final double size;

  @override
  Widget build(BuildContext context) {
    final url = _caaUrl(mbid);
    return ClipRRect(
      borderRadius: BorderRadius.circular(size * 0.18),
      child: url != null
          ? CachedNetworkImage(
              imageUrl: url,
              width: size,
              height: size,
              fit: BoxFit.cover,
              errorWidget: (_, __, ___) => _placeholder(),
            )
          : _placeholder(),
    );
  }

  Widget _placeholder() => Container(
        width: size,
        height: size,
        color: cs.surfaceContainerHighest,
        child: Icon(Icons.music_note_rounded,
            color: cs.primary.withValues(alpha: 0.4),
            size: size * 0.44),
      );
}

// ── LB track tile ─────────────────────────────────────────────────────────────

class _LBTrackTile extends StatelessWidget {
  const _LBTrackTile({
    required this.title,
    required this.artist,
    required this.cs,
    required this.isDark,
    required this.onTap,
    this.caaMbid,
    this.rank,
    this.right,
  });

  final String  title;
  final String  artist;
  final String? caaMbid;
  final int?    rank;
  final Widget? right;
  final ColorScheme cs;
  final bool isDark;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(16),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        child: Row(
          children: [
            // Rank number
            if (rank != null)
              SizedBox(
                width: 24,
                child: Text(
                  '$rank',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w700,
                    color: Colors.white.withValues(alpha: 0.35),
                  ),
                ),
              ),
            if (rank != null) const SizedBox(width: 8),
            _CaaArtwork(mbid: caaMbid, cs: cs, size: 50),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      fontWeight: FontWeight.w700,
                      fontSize: 14,
                      color: isDark ? Colors.white : cs.onSurface,
                    ),
                  ),
                  Text(
                    artist,
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
            if (right != null) ...[
              const SizedBox(width: 8),
              right!,
            ],
          ],
        ),
      ),
    );
  }
}

// ── Play count badge ──────────────────────────────────────────────────────────

class _PlayCountBadge extends StatelessWidget {
  const _PlayCountBadge({required this.count, required this.cs});
  final int count;
  final ColorScheme cs;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: cs.primary.withValues(alpha: 0.15),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Text(
        '$count plays',
        style: TextStyle(
          fontSize: 11,
          fontWeight: FontWeight.w600,
          color: cs.primary.withValues(alpha: 0.9),
        ),
      ),
    );
  }
}

// ── Favorites horizontal row ──────────────────────────────────────────────────

class _FavoritesRow extends StatelessWidget {
  const _FavoritesRow({
    required this.favorites,
    required this.cs,
    required this.isDark,
    required this.onTap,
  });
  final List<Track> favorites;
  final ColorScheme cs;
  final bool isDark;
  final void Function(int) onTap;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 200,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: 20),
        itemCount: favorites.length,
        separatorBuilder: (_, __) => const SizedBox(width: 14),
        itemBuilder: (context, i) {
          final track = favorites[i];
          return GestureDetector(
            onTap: () => onTap(i),
            child: GlassCard(
              padding: const EdgeInsets.all(10),
              opacity: 0.08,
              borderRadius: BorderRadius.circular(20),
              child: SizedBox(
                width: 130,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    ClipRRect(
                      borderRadius: BorderRadius.circular(12),
                      child: track.artwork != null
                          ? CachedNetworkImage(
                              imageUrl: track.artwork!,
                              width: 130,
                              height: 130,
                              fit: BoxFit.cover,
                              errorWidget: (_, __, ___) =>
                                  _placeholder(130, cs),
                            )
                          : _placeholder(130, cs),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      track.title,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        color: Colors.white,
                        fontWeight: FontWeight.w700,
                        fontSize: 13,
                        letterSpacing: -0.2,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Row(
                      children: [
                        Icon(Icons.favorite_rounded,
                            size: 10,
                            color: cs.primary.withValues(alpha: 0.7)),
                        const SizedBox(width: 4),
                        Expanded(
                          child: Text(
                            track.artist,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: TextStyle(
                              color: Colors.white.withValues(alpha: 0.5),
                              fontSize: 11,
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                        ),
                      ],
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

  Widget _placeholder(double size, ColorScheme cs) => Container(
        width: size,
        height: size,
        color: cs.surfaceContainerHighest,
        child: Icon(Icons.favorite_rounded,
            color: cs.primary.withValues(alpha: 0.3), size: size * 0.35),
      );
}

// ── Existing widgets (unchanged) ──────────────────────────────────────────────

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
                              errorWidget: (_, __, ___) =>
                                  _artPlaceholder(cs),
                            )
                          : _artPlaceholder(cs),
                    ),
                    const SizedBox(height: 10),
                    Text(
                      item['title'] ?? '—',
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
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
          baseColor: isDark
              ? const Color(0xFF1E1E1E)
              : const Color(0xFFE0E0E0),
          highlightColor: isDark
              ? const Color(0xFF2A2A2A)
              : const Color(0xFFEEEEEE),
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
              Container(width: 120, height: 12, color: Colors.white),
              const SizedBox(height: 4),
              Container(width: 80, height: 10, color: Colors.white),
            ],
          ),
        ),
      ),
    );
  }
}

class _LBListShimmer extends StatelessWidget {
  const _LBListShimmer({required this.isDark});
  final bool isDark;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20),
      child: Column(
        children: List.generate(
          5,
          (_) => Shimmer.fromColors(
            baseColor: isDark
                ? const Color(0xFF1E1E1E)
                : const Color(0xFFE0E0E0),
            highlightColor: isDark
                ? const Color(0xFF2A2A2A)
                : const Color(0xFFEEEEEE),
            child: Padding(
              padding: const EdgeInsets.symmetric(vertical: 8),
              child: Row(
                children: [
                  Container(
                    width: 50,
                    height: 50,
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(8),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Container(
                          width: 160, height: 12, color: Colors.white),
                      const SizedBox(height: 6),
                      Container(
                          width: 100, height: 10, color: Colors.white),
                    ],
                  ),
                ],
              ),
            ),
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
              size: 40,
              color: cs.onSurfaceVariant.withValues(alpha: 0.4)),
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
