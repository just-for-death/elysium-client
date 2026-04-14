import 'dart:ui';

import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter_hooks/flutter_hooks.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';

import '../../core/api/elysium_api.dart';
import '../../core/store/providers.dart';
import '../../core/widgets/glass_widgets.dart';
import 'video_player_view.dart';

enum _PlayerTab { cover, lyrics, queue }

class PlayerScreen extends HookConsumerWidget {
  const PlayerScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final player = ref.watch(playerProvider);
    final cs = Theme.of(context).colorScheme;
    final serverIp = ref.watch(serverIpProvider);
    final api = useMemoized(() => ElysiumApi(serverIp), [serverIp]);

    final track = player.currentTrack;
    final tab = useState(_PlayerTab.cover);
    final lyrics = useState<List<({double time, String text})>>([]);
    final lyricsLoading = useState(false);
    final lyricError = useState('');
    final activeLyricIdx = useState(0);
    final aiLoading = useState(false);
    final lyricsScrollCtrl = useScrollController();
    final artworkAnim = useAnimationController(
        duration: const Duration(milliseconds: 300));

    // Pulse artwork on track change
    useEffect(() {
      artworkAnim
        ..reset()
        ..forward();
      // Reset rotation on track change is handled by the widget state
      lyrics.value = [];
      lyricError.value = '';
      activeLyricIdx.value = 0;
      return null;
    }, [track?.effectiveId]);

    final rotationCtrl = useAnimationController(
        duration: const Duration(seconds: 20));

    useEffect(() {
      if (player.isPlaying) {
        rotationCtrl.repeat();
      } else {
        rotationCtrl.stop();
      }
      return null;
    }, [player.isPlaying]);

    // Lyrics fetch on tab switch
    useEffect(() {
      if (tab.value != _PlayerTab.lyrics || track == null) return null;
      if (lyrics.value.isNotEmpty) return null;
      lyricsLoading.value = true;
      lyricError.value = '';
      api
          .lyricsSearch('${track.title} ${track.artist}')
          .then((data) async {
        final songs = data?['result']?['songs'] as List<dynamic>?;
        if (songs == null || songs.isEmpty) {
          throw Exception('No lyrics found');
        }
        final id = songs[0]['id'].toString();
        final lyricData = await api.lyricsGet(id);
        final lrc = lyricData?['lrc']?['lyric'] as String? ?? '';
        final parsed = _parseLRC(lrc);
        if (parsed.isEmpty) throw Exception('Empty lyrics');
        lyrics.value = parsed;
      }).catchError((e) {
        lyricError.value = e.toString().replaceAll('Exception: ', '');
      }).whenComplete(() {
        lyricsLoading.value = false;
      });
      return null;
    }, [tab.value, track?.effectiveId]);

    // Active lyric tracking
    useEffect(() {
      if (lyrics.value.isEmpty) return null;
      final currentSec = player.position.inMilliseconds / 1000;
      int idx = 0;
      for (int i = lyrics.value.length - 1; i >= 0; i--) {
        if (lyrics.value[i].time <= currentSec) {
          idx = i;
          break;
        }
      }
      if (idx != activeLyricIdx.value) {
        activeLyricIdx.value = idx;
        _scrollToLyric(lyricsScrollCtrl, idx);
      }
      return null;
    }, [player.position]);

    final artworkUrl = track?.artwork ??
        'https://images.unsplash.com/photo-1618005182384-a83a8bd57fbe?w=600';

    final progress = player.duration.inMilliseconds > 0
        ? player.position.inMilliseconds / player.duration.inMilliseconds
        : 0.0;

    return Scaffold(
      backgroundColor: Colors.black,
      body: Stack(
        fit: StackFit.expand,
        children: [
          // Blurred background artwork
          if (track?.artwork != null)
            CachedNetworkImage(
              imageUrl: track!.artwork!,
              fit: BoxFit.cover,
              errorWidget: (_, __, ___) => const SizedBox.shrink(),
            ),
          BackdropFilter(
            filter: ImageFilter.blur(sigmaX: 60, sigmaY: 60),
            child: Container(
                color: Colors.black.withValues(alpha: 0.7)),
          ),

          // Content
          SafeArea(
            child: Column(
              children: [
                // Header
                Padding(
                  padding: const EdgeInsets.symmetric(
                      horizontal: 8, vertical: 4),
                  child: Row(
                    children: [
                      IconButton(
                        icon: const Icon(Icons.keyboard_arrow_down_rounded,
                            size: 32,
                            color: Colors.white),
                        onPressed: () => Navigator.pop(context),
                      ),
                      Expanded(
                        child: Text(
                          track?.album ?? 'Now Playing',
                          textAlign: TextAlign.center,
                          style: const TextStyle(
                            color: Colors.white60,
                            fontSize: 12,
                            fontWeight: FontWeight.w700,
                            letterSpacing: 1,
                          ),
                        ),
                      ),
                      // Video Toggle
                      IconButton(
                        icon: Icon(
                          player.videoMode
                              ? Icons.videocam_rounded
                              : Icons.videocam_outlined,
                          size: 22,
                          color: player.videoMode
                              ? cs.primary
                              : Colors.white60,
                        ),
                        onPressed: track == null
                            ? null
                            : () => ref
                                .read(playerProvider.notifier)
                                .toggleVideoMode(),
                      ),
                      IconButton(
                        icon: Icon(
                          aiLoading.value
                              ? Icons.hourglass_top_rounded
                              : Icons.auto_awesome_rounded,
                          size: 22,
                          color: aiLoading.value
                              ? cs.primary
                              : Colors.white60,
                        ),
                        onPressed: aiLoading.value || track == null
                            ? null
                            : () async {
                                aiLoading.value = true;
                                try {
                                  final aiTrack =
                                      await api.generateAIQueue(track);
                                  if (aiTrack != null) {
                                    final q = [...player.queue];
                                    q.insert(
                                        player.currentIndex + 1, aiTrack);
                                    ref
                                        .read(playerProvider.notifier)
                                        .setQueue(q);
                                  }
                                } finally {
                                  aiLoading.value = false;
                                }
                              },
                      ),
                    ],
                  ),
                ),

                // Tab pills with more visual appeal
                Padding(
                  padding: const EdgeInsets.symmetric(vertical: 8),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: _PlayerTab.values
                        .map((t) => Padding(
                              padding: const EdgeInsets.symmetric(horizontal: 4),
                              child: _PlayerTabPill(
                                label: _tabLabel(t),
                                selected: tab.value == t,
                                onTap: () => tab.value = t,
                                cs: cs,
                              ),
                            ))
                        .toList(),
                  ),
                ),
                const SizedBox(height: 8),

                // Main area
                Expanded(
                  child: _buildTabContent(
                    context,
                    ref,
                    tab.value,
                    player,
                    artworkUrl,
                    lyrics,
                    lyricsLoading,
                    lyricError,
                    activeLyricIdx,
                    lyricsScrollCtrl,
                    artworkAnim,
                    rotationCtrl,
                    cs,
                  ),
                ),

                // Track info + favorite
                Padding(
                  padding: const EdgeInsets.symmetric(
                      horizontal: 24, vertical: 4),
                  child: Row(
                    children: [
                      Expanded(
                        child: Column(
                          crossAxisAlignment:
                              CrossAxisAlignment.start,
                          children: [
                            Text(
                              track?.title ?? '—',
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: const TextStyle(
                                color: Colors.white,
                                fontSize: 22,
                                fontWeight: FontWeight.w800,
                                letterSpacing: -0.3,
                              ),
                            ),
                            const SizedBox(height: 2),
                            Text(
                              track?.artist ?? 'Unknown Artist',
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: const TextStyle(
                                color: Colors.white60,
                                fontSize: 15,
                                fontWeight: FontWeight.w500,
                              ),
                            ),
                          ],
                        ),
                      ),
                      if (track != null)
                        IconButton(
                          icon: Icon(
                            player.isFavorite(track.effectiveId)
                                ? Icons.favorite_rounded
                                : Icons.favorite_border_rounded,
                            size: 28,
                            color: player.isFavorite(track.effectiveId)
                                ? Colors.redAccent
                                : Colors.white60,
                          ),
                          onPressed: () async {
                            final fav = player.isFavorite(track.effectiveId);
                            if (fav) {
                              await api
                                  .deleteFavorite(track.effectiveId)
                                  .catchError((_) {});
                              ref
                                  .read(playerProvider.notifier)
                                  .removeFavorite(track.effectiveId);
                            } else {
                              await api
                                  .addFavorite(track)
                                  .catchError((_) {});
                              ref
                                  .read(playerProvider.notifier)
                                  .addFavorite(track);
                            }
                          },
                        ),
                    ],
                  ),
                ),

                // Progress bar with improved interaction
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 24),
                  child: Column(
                    children: [
                      GestureDetector(
                        onHorizontalDragUpdate: (details) {
                          // Seek while dragging for immediate feedback
                          final box = context.findRenderObject() as RenderBox;
                          final width = box.size.width;
                          final dx = details.localPosition.dx.clamp(0.0, width);
                          final fraction = dx / width;
                          final target = Duration(
                            milliseconds: (fraction * player.duration.inMilliseconds).toInt()
                          );
                          ref.read(playerProvider.notifier).seekTo(target);
                        },
                        child: Container(
                          height: 30,
                          alignment: Alignment.center,
                          child: SliderTheme(
                            data: SliderTheme.of(context).copyWith(
                              trackHeight: 4,
                              thumbShape: const RoundSliderThumbShape(
                                  enabledThumbRadius: 6),
                              overlayShape: const RoundSliderOverlayShape(
                                  overlayRadius: 14),
                              activeTrackColor: Colors.white,
                              inactiveTrackColor:
                                  Colors.white.withValues(alpha: 0.25),
                              thumbColor: Colors.white,
                              trackShape: const RoundedRectSliderTrackShape(),
                            ),
                            child: Slider(
                              value: progress.clamp(0.0, 1.0),
                              onChanged: (v) {
                                final target = Duration(
                                    milliseconds: (v *
                                            player.duration.inMilliseconds)
                                        .toInt());
                                ref
                                    .read(playerProvider.notifier)
                                    .seekTo(target);
                              },
                            ),
                          ),
                        ),
                      ),
                      Row(
                        mainAxisAlignment:
                            MainAxisAlignment.spaceBetween,
                        children: [
                          Text(_fmt(player.position),
                              style: const TextStyle(
                                  color: Colors.white60,
                                  fontSize: 11,
                                  fontWeight: FontWeight.w600)),
                          // Duration indicator
                          Text(
                            _fmt(player.duration),
                              style: const TextStyle(
                                  color: Colors.white38,
                                  fontSize: 11,
                                  fontWeight: FontWeight.w600)),
                        ],
                      ),
                    ],
                  ),
                ),

                // Controls
                Padding(
                  padding: const EdgeInsets.fromLTRB(24, 4, 24, 16),
                  child: Row(
                    mainAxisAlignment:
                        MainAxisAlignment.spaceBetween,
                    children: [
                      // Shuffle
                      IconButton(
                        icon: Icon(
                          Icons.shuffle_rounded,
                          size: 24,
                          color: player.shuffled
                              ? cs.primary
                              : Colors.white.withValues(alpha: 0.5),
                        ),
                        onPressed: () =>
                            ref.read(playerProvider.notifier).toggleShuffle(),
                      ),
                      // Previous
                      IconButton(
                        icon: const Icon(Icons.skip_previous_rounded,
                            size: 44, color: Colors.white),
                        onPressed: () =>
                            ref.read(playerProvider.notifier).previous(),
                      ),
                      // Play/Pause
                      GestureDetector(
                        onTap: () =>
                            ref.read(playerProvider.notifier).togglePlayPause(),
                        child: Container(
                          width: 72,
                          height: 72,
                          decoration: const BoxDecoration(
                            color: Colors.white,
                            shape: BoxShape.circle,
                          ),
                          child: Icon(
                            player.isPlaying
                                ? Icons.pause_rounded
                                : Icons.play_arrow_rounded,
                            size: 38,
                            color: Colors.black,
                          ),
                        ),
                      ),
                      // Next
                      IconButton(
                        icon: const Icon(Icons.skip_next_rounded,
                            size: 44, color: Colors.white),
                        onPressed: () =>
                            ref.read(playerProvider.notifier).next(),
                      ),
                      // Repeat
                      IconButton(
                        icon: Icon(
                          _repeatIcon(player.repeatMode),
                          size: 24,
                          color: player.repeatMode != ElysiumRepeatMode.off
                              ? cs.primary
                              : Colors.white.withValues(alpha: 0.5),
                        ),
                        onPressed: () =>
                            ref.read(playerProvider.notifier).cycleRepeat(),
                      ),

                      // Video Toggle
                      IconButton(
                        icon: Icon(
                          player.videoMode
                              ? Icons.videocam_rounded
                              : Icons.videocam_outlined,
                          size: 24,
                          color: player.videoMode
                              ? cs.primary
                              : Colors.white.withValues(alpha: 0.5),
                        ),
                        onPressed: () =>
                            ref.read(playerProvider.notifier).toggleVideoMode(),
                      ),
                    ],
                  ),
                ),

                const SizedBox(height: 8),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildTabContent(
    BuildContext context,
    WidgetRef ref,
    _PlayerTab tab,
    PlayerState player,
    String artworkUrl,
    ValueNotifier<List<({double time, String text})>> lyrics,
    ValueNotifier<bool> lyricsLoading,
    ValueNotifier<String> lyricError,
    ValueNotifier<int> activeLyricIdx,
    ScrollController scrollCtrl,
    AnimationController artworkAnim,
    AnimationController rotationCtrl,
    ColorScheme cs,
  ) {
    switch (tab) {
      case _PlayerTab.cover:
        if (player.videoMode) {
          return const Center(
            child: Padding(
              padding: EdgeInsets.symmetric(horizontal: 16, vertical: 24),
              child: AspectRatio(
                aspectRatio: 16 / 9,
                child: ClipRRect(
                  borderRadius: BorderRadius.all(Radius.circular(12)),
                  child: VideoPlayerView(),
                ),
              ),
            ),
          );
        }
        return Center(
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 40),
            child: AspectRatio(
              aspectRatio: 1,
              child: Stack(
                alignment: Alignment.center,
                children: [
                   // Shadow/Glow
                  Container(
                    width: double.infinity,
                    height: double.infinity,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withValues(alpha: 0.5),
                          blurRadius: 30,
                          spreadRadius: 5,
                        )
                      ],
                    ),
                  ),
                  RotationTransition(
                    turns: rotationCtrl,
                    child: ScaleTransition(
                      scale: CurvedAnimation(
                          parent: artworkAnim, curve: Curves.elasticOut),
                      child: Container(
                        padding: const EdgeInsets.all(8),
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          color: const Color(0xFF1A1A1A),
                          border: Border.all(color: Colors.white10, width: 2),
                        ),
                        child: ClipOval(
                          child: CachedNetworkImage(
                            imageUrl: artworkUrl,
                            fit: BoxFit.cover,
                            errorWidget: (_, __, ___) => Container(
                              color: cs.surfaceContainerHighest,
                              child: Icon(Icons.music_note_rounded,
                                  size: 80,
                                  color: cs.primary.withValues(alpha: 0.4)),
                            ),
                          ),
                        ),
                      ),
                    ),
                  ),
                  // Center hole
                  Container(
                    width: 20,
                    height: 20,
                    decoration: BoxDecoration(
                      color: Colors.black,
                      shape: BoxShape.circle,
                      border: Border.all(color: Colors.white24, width: 1),
                    ),
                  ),
                ],
              ),
            ),
          ),
        );

      case _PlayerTab.lyrics:
        if (lyricsLoading.value) {
          return const Center(
              child: CircularProgressIndicator(color: Colors.white60));
        }
        if (lyricError.value.isNotEmpty) {
          return Center(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Icon(Icons.music_note_rounded,
                    size: 40, color: Colors.white24),
                const SizedBox(height: 12),
                Text(lyricError.value,
                    style: const TextStyle(
                        color: Colors.white38, fontSize: 14)),
              ],
            ),
          );
        }
        if (lyrics.value.isEmpty) {
          return const Center(
            child: Text('Tap Lyrics tab to fetch',
                style: TextStyle(color: Colors.white38)),
          );
        }
        return ListView.builder(
          controller: scrollCtrl,
          padding: const EdgeInsets.symmetric(
              horizontal: 24, vertical: 40),
          itemCount: lyrics.value.length,
          itemBuilder: (context, i) {
            final isActive = i == activeLyricIdx.value;
            final delta = (i - activeLyricIdx.value).abs();
            return Padding(
              padding: const EdgeInsets.symmetric(vertical: 8),
              child: Text(
                lyrics.value[i].text,
                style: TextStyle(
                  color: Colors.white
                      .withValues(alpha: isActive ? 1 : (0.6 - delta * 0.1).clamp(0.1, 0.6)),
                  fontSize: isActive ? 22 : 18,
                  fontWeight: isActive
                      ? FontWeight.w700
                      : FontWeight.w500,
                  height: 1.4,
                ),
              ),
            );
          },
        );

      case _PlayerTab.queue:
        if (player.queue.isEmpty) {
          return const Center(
            child: Text('Queue is empty',
                style: TextStyle(color: Colors.white38)),
          );
        }
        return ListView.builder(
          padding: const EdgeInsets.symmetric(vertical: 8),
          itemCount: player.queue.length,
          itemBuilder: (context, i) {
            final t = player.queue[i];
            final isActive = i == player.currentIndex;
            return ListTile(
              contentPadding:
                  const EdgeInsets.symmetric(horizontal: 16, vertical: 2),
              leading: ClipRRect(
                borderRadius: BorderRadius.circular(8),
                child: t.artwork != null
                    ? CachedNetworkImage(
                        imageUrl: t.artwork!,
                        width: 44,
                        height: 44,
                        fit: BoxFit.cover,
                        errorWidget: (_, __, ___) => Container(
                          width: 44,
                          height: 44,
                          color: Colors.white12,
                          child: const Icon(Icons.music_note_rounded,
                              color: Colors.white38, size: 20),
                        ),
                      )
                    : Container(
                        width: 44,
                        height: 44,
                        color: Colors.white12,
                        child: const Icon(Icons.music_note_rounded,
                            color: Colors.white38, size: 20),
                      ),
              ),
              title: Text(
                t.title,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  color: isActive ? cs.primary : Colors.white,
                  fontWeight: FontWeight.w600,
                  fontSize: 14,
                ),
              ),
              subtitle: Text(
                t.artist,
                maxLines: 1,
                style: const TextStyle(
                    color: Colors.white54, fontSize: 12),
              ),
              trailing: isActive
                  ? Icon(Icons.equalizer_rounded,
                      color: cs.primary, size: 20)
                  : null,
              onTap: () =>
                  ref.read(playerProvider.notifier).playIndex(i),
            );
          },
        );
    }
  }

  String _tabLabel(_PlayerTab t) {
    switch (t) {
      case _PlayerTab.cover:
        return '♫ Cover';
      case _PlayerTab.lyrics:
        return '☰ Lyrics';
      case _PlayerTab.queue:
        return '≡ Queue';
    }
  }

  IconData _repeatIcon(ElysiumRepeatMode mode) {
    switch (mode) {
      case ElysiumRepeatMode.off:
        return Icons.repeat_rounded;
      case ElysiumRepeatMode.all:
        return Icons.repeat_rounded;
      case ElysiumRepeatMode.one:
        return Icons.repeat_one_rounded;
    }
  }

  String _fmt(Duration d) {
    final m = d.inMinutes;
    final s = d.inSeconds % 60;
    return '$m:${s.toString().padLeft(2, '0')}';
  }

  List<({double time, String text})> _parseLRC(String lrc) {
    final result = <({double time, String text})>[];
    for (final line in lrc.split('\n')) {
      final m = RegExp(r'\[(\d+):(\d+(?:\.\d+)?)\](.*)').firstMatch(line);
      if (m != null) {
        final time =
            int.parse(m.group(1)!) * 60 + double.parse(m.group(2)!);
        final text = m.group(3)!.trim();
        if (text.isNotEmpty) result.add((time: time, text: text));
      }
    }
    result.sort((a, b) => a.time.compareTo(b.time));
    return result;
  }

  void _scrollToLyric(ScrollController ctrl, int idx) {
    if (!ctrl.hasClients) return;
    final offset = (idx * 60.0)
        .clamp(0.0, ctrl.position.maxScrollExtent);
    ctrl.animateTo(
      offset,
      duration: const Duration(milliseconds: 300),
      curve: Curves.easeOutCubic,
    );
  }
}

class _PlayerTabPill extends StatelessWidget {
  const _PlayerTabPill({
    required this.label,
    required this.selected,
    required this.onTap,
  });
  final String label;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        margin: const EdgeInsets.symmetric(horizontal: 4),
        padding:
            const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
        decoration: BoxDecoration(
          color: selected
              ? Colors.white.withValues(alpha: 0.25)
              : Colors.white.withValues(alpha: 0.08),
          borderRadius: BorderRadius.circular(20),
        ),
        child: Text(
          label,
          style: TextStyle(
            color:
                selected ? Colors.white : Colors.white.withValues(alpha: 0.5),
            fontWeight:
                selected ? FontWeight.w700 : FontWeight.w500,
            fontSize: 13,
          ),
        ),
      ),
    );
  }
}
