import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter_hooks/flutter_hooks.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';

import '../../core/api/elysium_api.dart';
import '../../core/models/models.dart';
import '../../core/models/track.dart';
import '../../core/store/providers.dart';
import '../../core/widgets/glass_widgets.dart';

enum _LibTab { favorites, playlists, artists, albums }

class LibraryScreen extends HookConsumerWidget {
  const LibraryScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final serverIp = ref.watch(serverIpProvider);
    final api = useMemoized(() => ElysiumApi(serverIp), [serverIp]);
    final cs = Theme.of(context).colorScheme;
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final playerState = ref.watch(playerProvider);

    final tab = useState(_LibTab.favorites);
    final favorites = useState<List<Track>>([]);
    final playlists = useState<List<Playlist>>([]);
    final artists = useState<List<Artist>>([]);
    final albums = useState<List<Album>>([]);
    final loading = useState(true);

    Future<void> loadAll() async {
      loading.value = true;
      try {
        final results = await Future.wait([
          api.getFavorites().catchError((_) => <Track>[]),
          api.getPlaylists().catchError((_) => <Playlist>[]),
          api.getArtists().catchError((_) => <Artist>[]),
          api.getAlbums().catchError((_) => <Album>[]),
        ]);
        favorites.value = results[0] as List<Track>;
        playlists.value = results[1] as List<Playlist>;
        artists.value = results[2] as List<Artist>;
        albums.value = results[3] as List<Album>;

        // Sync favorites into player state
        ref
            .read(playerProvider.notifier)
            .setFavorites(favorites.value);
      } finally {
        loading.value = false;
      }
    }

    useEffect(() {
      loadAll();
      return null;
    }, [serverIp]);

    return PremiumBackground(
      child: SafeArea(
        bottom: false,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Header
            Padding(
              padding: const EdgeInsets.fromLTRB(24, 32, 24, 16),
              child: Row(
                children: [
                  Expanded(
                    child: Text(
                      'Your Library',
                      style: TextStyle(
                        fontSize: 34,
                        fontWeight: FontWeight.w900,
                        color: Colors.white,
                        letterSpacing: -1,
                      ),
                    ),
                  ),
                  if (tab.value == _LibTab.playlists)
                    GlassCard(
                      padding: EdgeInsets.zero,
                      borderRadius: BorderRadius.circular(12),
                      child: IconButton(
                        icon: Icon(Icons.add_rounded, color: cs.primary),
                        onPressed: () => _createPlaylistDialog(
                            context, api, playlists),
                      ),
                    ),
                ],
              ),
            ),

            // Tab pills
            SizedBox(
              height: 48,
              child: ListView(
                scrollDirection: Axis.horizontal,
                padding: const EdgeInsets.symmetric(horizontal: 24),
                children: _LibTab.values
                    .map((t) => Padding(
                          padding: const EdgeInsets.only(right: 10),
                          child: GlassPill(
                            label: _tabLabel(t),
                            selected: tab.value == t,
                            onTap: () => tab.value = t,
                          ),
                        ))
                    .toList(),
              ),
            ),
            const SizedBox(height: 16),

            // Content
            Expanded(
              child: RefreshIndicator(
                onRefresh: loadAll,
                color: cs.primary,
                backgroundColor: Colors.white,
                child: loading.value
                    ? Center(
                        child: CircularProgressIndicator(
                            color: cs.primary))
                    : _buildTabContent(
                        context,
                        ref,
                        tab.value,
                        favorites,
                        playlists,
                        artists,
                        albums,
                        api,
                        cs,
                        isDark,
                        playerState,
                      ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  String _tabLabel(_LibTab t) {
    switch (t) {
      case _LibTab.favorites:
        return '♥ Favorites';
      case _LibTab.playlists:
        return '≡ Playlists';
      case _LibTab.artists:
        return '👤 Artists';
      case _LibTab.albums:
        return '💿 Albums';
    }
  }

  Widget _buildTabContent(
    BuildContext context,
    WidgetRef ref,
    _LibTab tab,
    ValueNotifier<List<Track>> favorites,
    ValueNotifier<List<Playlist>> playlists,
    ValueNotifier<List<Artist>> artists,
    ValueNotifier<List<Album>> albums,
    ElysiumApi api,
    ColorScheme cs,
    bool isDark,
    PlayerState playerState,
  ) {
    switch (tab) {
      case _LibTab.favorites:
        return _TrackList(
          tracks: favorites.value,
          cs: cs,
          isDark: isDark,
          emptyMessage: 'No favorites yet.\nHeart a track while it plays.',
          emptyIcon: Icons.favorite_border_rounded,
          onTap: (index) {
            ref.read(playerProvider.notifier).setQueue(favorites.value);
            ref.read(playerProvider.notifier).playIndex(index);
          },
          trailing: (track) => IconButton(
            icon: Icon(Icons.favorite_rounded,
                color: Colors.redAccent, size: 22),
            onPressed: () async {
              await api
                  .deleteFavorite(track.effectiveId)
                  .catchError((_) {});
              favorites.value = favorites.value
                  .where(
                      (f) => f.effectiveId != track.effectiveId)
                  .toList();
              ref
                  .read(playerProvider.notifier)
                  .removeFavorite(track.effectiveId);
            },
          ),
        );

      case _LibTab.playlists:
        if (playlists.value.isEmpty) {
          return _EmptyState(
            icon: Icons.queue_music_rounded,
            message: 'No playlists yet.\nTap + to create one.',
            cs: cs,
          );
        }
        return ListView.builder(
          padding: const EdgeInsets.fromLTRB(16, 8, 16, 160),
          itemCount: playlists.value.length,
          itemBuilder: (context, i) {
            final pl = playlists.value[i];
            return Padding(
              padding: const EdgeInsets.only(bottom: 12),
              child: GlassCard(
                opacity: 0.05,
                borderRadius: BorderRadius.circular(16),
                child: ListTile(
                  leading: Container(
                    width: 50,
                    height: 50,
                    decoration: BoxDecoration(
                      color: cs.primary.withValues(alpha: 0.15),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Icon(Icons.queue_music_rounded,
                        color: cs.primary),
                  ),
                  title: Text(pl.title,
                      style: const TextStyle(
                          fontWeight: FontWeight.w700,
                          color: Colors.white)),
                  subtitle: Text(
                      '${pl.videos.length} tracks',
                      style: TextStyle(color: Colors.white.withValues(alpha: 0.5))),
                  trailing: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      IconButton(
                        icon: Icon(Icons.cloud_upload_outlined, color: cs.primary, size: 20),
                        onPressed: () async {
                          final sc = ScaffoldMessenger.of(context);
                          sc.showSnackBar(const SnackBar(content: Text('Syncing to ListenBrainz...')));
                          try {
                            await api.syncPlaylistToListenBrainz(pl.id);
                            sc.showSnackBar(const SnackBar(content: Text('Synced to ListenBrainz ✓')));
                          } catch (e) {
                            sc.showSnackBar(SnackBar(content: Text('Sync failed: $e')));
                          }
                        },
                      ),
                      IconButton(
                        icon: Icon(Icons.delete_outline_rounded,
                            color: Colors.redAccent.withValues(alpha: 0.7), size: 20),
                        onPressed: () async {
                          await api
                              .deletePlaylist(pl.id)
                              .catchError((_) {});
                          playlists.value = playlists.value
                              .where((p) => p.id != pl.id)
                              .toList();
                        },
                      ),
                    ],
                  ),
                  onTap: () {
                    if (pl.videos.isNotEmpty) {
                      ref
                          .read(playerProvider.notifier)
                          .setQueue(pl.videos);
                      ref.read(playerProvider.notifier).playIndex(0);
                    }
                  },
                ),
              ),
            );
          },
        );

      case _LibTab.artists:
        if (artists.value.isEmpty) {
          return _EmptyState(
            icon: Icons.person_outline_rounded,
            message: 'No artists saved yet.',
            cs: cs,
          );
        }
        return GridView.builder(
          padding: const EdgeInsets.fromLTRB(16, 8, 16, 160),
          gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
            crossAxisCount: 2,
            childAspectRatio: 1,
            crossAxisSpacing: 12,
            mainAxisSpacing: 12,
          ),
          itemCount: artists.value.length,
          itemBuilder: (context, i) {
            final artist = artists.value[i];
            return Column(
              children: [
                ClipOval(
                  child: artist.artwork != null
                      ? CachedNetworkImage(
                          imageUrl: artist.artwork!,
                          width: 110,
                          height: 110,
                          fit: BoxFit.cover,
                          errorWidget: (_, __, ___) =>
                              _circularPlaceholder(cs),
                        )
                      : _circularPlaceholder(cs),
                ),
                const SizedBox(height: 8),
                Text(
                  artist.name,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    fontWeight: FontWeight.w700,
                    color: isDark ? Colors.white : cs.onSurface,
                  ),
                ),
              ],
            );
          },
        );

      case _LibTab.albums:
        if (albums.value.isEmpty) {
          return _EmptyState(
            icon: Icons.album_rounded,
            message: 'No albums saved yet.',
            cs: cs,
          );
        }
        return GridView.builder(
          padding: const EdgeInsets.fromLTRB(16, 8, 16, 160),
          gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
            crossAxisCount: 2,
            childAspectRatio: 0.75,
            crossAxisSpacing: 12,
            mainAxisSpacing: 12,
          ),
          itemCount: albums.value.length,
          itemBuilder: (context, i) {
            final album = albums.value[i];
            return GestureDetector(
              onTap: () {
                if (album.tracks != null && album.tracks!.isNotEmpty) {
                  ref
                      .read(playerProvider.notifier)
                      .setQueue(album.tracks!);
                  ref.read(playerProvider.notifier).playIndex(0);
                }
              },
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  ClipRRect(
                    borderRadius: BorderRadius.circular(12),
                    child: album.artwork != null
                        ? CachedNetworkImage(
                            imageUrl: album.artwork!,
                            width: double.infinity,
                            height: 130,
                            fit: BoxFit.cover,
                            errorWidget: (_, __, ___) =>
                                _rectPlaceholder(cs),
                          )
                        : _rectPlaceholder(cs),
                  ),
                  const SizedBox(height: 6),
                  Text(
                    album.title,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      fontWeight: FontWeight.w700,
                      fontSize: 13,
                      color: isDark ? Colors.white : cs.onSurface,
                    ),
                  ),
                  Text(
                    album.artist,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                        fontSize: 12, color: cs.onSurfaceVariant),
                  ),
                ],
              ),
            );
          },
        );
    }
  }

  Future<void> _createPlaylistDialog(
    BuildContext context,
    ElysiumApi api,
    ValueNotifier<List<Playlist>> playlists,
  ) async {
    final ctrl = TextEditingController();
    final title = await showDialog<String>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('New Playlist'),
        content: TextField(
          controller: ctrl,
          autofocus: true,
          decoration:
              const InputDecoration(hintText: 'Playlist name'),
        ),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(ctx),
              child: const Text('Cancel')),
          TextButton(
              onPressed: () => Navigator.pop(ctx, ctrl.text),
              child: const Text('Create')),
        ],
      ),
    );
    if (title != null && title.trim().isNotEmpty) {
      final pl = await api
          .createPlaylist(title.trim())
          .catchError((_) => Playlist(id: '', title: title.trim()));
      if (pl.id.isNotEmpty) {
        playlists.value = [...playlists.value, pl];
      }
    }
  }

  Widget _circularPlaceholder(ColorScheme cs) => Container(
        width: 110,
        height: 110,
        color: cs.surfaceContainerHighest,
        child: Icon(Icons.person_rounded,
            color: cs.primary.withValues(alpha: 0.4), size: 40),
      );

  Widget _rectPlaceholder(ColorScheme cs) => Container(
        width: double.infinity,
        height: 130,
        color: cs.surfaceContainerHighest,
        child: Icon(Icons.album_rounded,
            color: cs.primary.withValues(alpha: 0.4), size: 40),
      );
}

class _TabPill extends StatelessWidget {
  const _TabPill({
    required this.label,
    required this.selected,
    required this.cs,
    required this.isDark,
    required this.onTap,
  });
  final String label;
  final bool selected;
  final ColorScheme cs;
  final bool isDark;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        margin: const EdgeInsets.only(right: 8),
        padding:
            const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        decoration: BoxDecoration(
          color: selected
              ? cs.primary
              : isDark
                  ? Colors.white.withValues(alpha: 0.08)
                  : cs.surfaceContainerHigh,
          borderRadius: BorderRadius.circular(20),
        ),
        child: Text(
          label,
          style: TextStyle(
            fontSize: 13,
            fontWeight: FontWeight.w600,
            color: selected
                ? cs.onPrimary
                : isDark
                    ? Colors.white.withValues(alpha: 0.7)
                    : cs.onSurfaceVariant,
          ),
        ),
      ),
    );
  }
}

class _TrackList extends StatelessWidget {
  const _TrackList({
    required this.tracks,
    required this.cs,
    required this.isDark,
    required this.emptyMessage,
    required this.emptyIcon,
    required this.onTap,
    required this.trailing,
  });
  final List<Track> tracks;
  final ColorScheme cs;
  final bool isDark;
  final String emptyMessage;
  final IconData emptyIcon;
  final void Function(int) onTap;
  final Widget Function(Track) trailing;

  @override
  Widget build(BuildContext context) {
    if (tracks.isEmpty) {
      return _EmptyState(
          icon: emptyIcon, message: emptyMessage, cs: cs);
    }
    return ListView.builder(
      padding: const EdgeInsets.only(bottom: 160),
      itemCount: tracks.length,
      itemBuilder: (context, i) {
        final track = tracks[i];
        return ListTile(
          contentPadding:
              const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
          leading: ClipRRect(
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
          title: Text(
            track.title,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(
              fontWeight: FontWeight.w700,
              fontSize: 14,
              color: isDark ? Colors.white : cs.onSurface,
            ),
          ),
          subtitle: Text(
            track.artist,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(
                fontSize: 12, color: cs.onSurfaceVariant),
          ),
          trailing: trailing(track),
          onTap: () => onTap(i),
        );
      },
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

class _EmptyState extends StatelessWidget {
  const _EmptyState({
    required this.icon,
    required this.message,
    required this.cs,
  });
  final IconData icon;
  final String message;
  final ColorScheme cs;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon,
              size: 52,
              color: cs.onSurfaceVariant.withValues(alpha: 0.3)),
          const SizedBox(height: 16),
          Text(
            message,
            textAlign: TextAlign.center,
            style: TextStyle(
                color: cs.onSurfaceVariant.withValues(alpha: 0.5)),
          ),
        ],
      ),
    );
  }
}
