import 'dart:ui';

import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../core/store/providers.dart';

class MiniPlayer extends ConsumerWidget {
  const MiniPlayer({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final player = ref.watch(playerProvider);
    final track = player.currentTrack;
    if (track == null) return const SizedBox.shrink();

    final cs = Theme.of(context).colorScheme;
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final progress = player.duration.inMilliseconds > 0
        ? player.position.inMilliseconds / player.duration.inMilliseconds
        : 0.0;

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 12),
      child: GestureDetector(
        onTap: () => context.push('/player'),
        onVerticalDragEnd: (details) {
          // Swipe up to open player
          if (details.velocity.pixelsPerSecond.dy < -100) {
            context.push('/player');
          }
        },
        child: ClipRRect(
          borderRadius: BorderRadius.circular(16),
          child: BackdropFilter(
            filter: ImageFilter.blur(sigmaX: 20, sigmaY: 20),
            child: Container(
              height: 72,
              decoration: BoxDecoration(
                color: isDark
                    ? cs.surfaceContainer.withValues(alpha: 0.85)
                    : cs.surfaceContainerHigh.withValues(alpha: 0.9),
                borderRadius: BorderRadius.circular(16),
                border: Border.all(
                  color: isDark
                      ? Colors.white.withValues(alpha: 0.08)
                      : Colors.black.withValues(alpha: 0.06),
                  width: 0.5,
                ),
                // Subtle gradient for depth
                gradient: LinearGradient(
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                  colors: [
                    (isDark ? Colors.white : Colors.black).withValues(alpha: 0.05),
                    Colors.transparent,
                  ],
                ),
              ),
              child: Stack(
                children: [
                  // Progress line at bottom
                  Positioned(
                    left: 0,
                    right: 0,
                    bottom: 0,
                    child: ClipRRect(
                      borderRadius: const BorderRadius.only(
                        bottomLeft: Radius.circular(16),
                        bottomRight: Radius.circular(16),
                      ),
                      child: LinearProgressIndicator(
                        value: progress.clamp(0.0, 1.0),
                        minHeight: 2,
                        backgroundColor: Colors.transparent,
                        color: cs.primary.withValues(alpha: 0.6),
                      ),
                    ),
                  ),
                  // Content
                  Padding(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                    child: Row(
                      children: [
                        // Artwork with playing indicator
                        Stack(
                          children: [
                            ClipRRect(
                              borderRadius: BorderRadius.circular(10),
                              child: track.artwork != null
                                  ? CachedNetworkImage(
                                      imageUrl: track.artwork!,
                                      width: 48,
                                      height: 48,
                                      fit: BoxFit.cover,
                                      errorWidget: (_, __, ___) =>
                                          _artworkPlaceholder(cs),
                                    )
                                  : _artworkPlaceholder(cs),
                            ),
                            // Playing indicator overlay
                            if (player.isPlaying)
                              Positioned.fill(
                                child: ClipRRect(
                                  borderRadius: BorderRadius.circular(10),
                                  child: Container(
                                    color: Colors.black.withValues(alpha: 0.3),
                                    child: const Center(
                                      child: _PlayingIndicator(),
                                    ),
                                  ),
                                ),
                              ),
                          ],
                        ),
                        const SizedBox(width: 12),
                        // Title + artist
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Text(
                                track.title,
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: TextStyle(
                                  fontWeight: FontWeight.w700,
                                  fontSize: 14,
                                  color: player.isPlaying
                                      ? cs.primary
                                      : cs.onSurface,
                                ),
                              ),
                              const SizedBox(height: 2),
                              Text(
                                track.artist,
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: TextStyle(
                                  fontSize: 12,
                                  color: cs.onSurfaceVariant,
                                ),
                              ),
                            ],
                          ),
                        ),
                        // Controls
                        IconButton(
                          icon: Icon(
                            player.isPlaying
                                ? Icons.pause_rounded
                                : Icons.play_arrow_rounded,
                            size: 28,
                            color: cs.onSurface,
                          ),
                          onPressed: () =>
                              ref.read(playerProvider.notifier).togglePlayPause(),
                        ),
                        IconButton(
                          icon: Icon(Icons.skip_next_rounded,
                              size: 26, color: cs.onSurfaceVariant),
                          onPressed: () =>
                              ref.read(playerProvider.notifier).next(),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _artworkPlaceholder(ColorScheme cs) => Container(
        width: 48,
        height: 48,
        color: cs.surfaceContainerHighest,
        child: Icon(Icons.music_note_rounded,
            color: cs.primary.withValues(alpha: 0.6), size: 24),
      );
}

// Animated playing indicator (3 bouncing bars)
class _PlayingIndicator extends StatefulWidget {
  const _PlayingIndicator();

  @override
  State<_PlayingIndicator> createState() => _PlayingIndicatorState();
}

class _PlayingIndicatorState extends State<_PlayingIndicator>
    with TickerProviderStateMixin {
  late List<AnimationController> _controllers;
  late List<Animation<double>> _animations;

  @override
  void initState() {
    super.initState();
    _controllers = List.generate(3, (i) => AnimationController(
      duration: Duration(milliseconds: 300 + (i * 100)),
      vsync: this,
    ));
    _animations = _controllers.map((c) =>
      Tween<double>(begin: 0.3, end: 1.0).animate(
        CurvedAnimation(parent: c, curve: Curves.easeInOut),
      )
    ).toList();

    // Start animations with staggered delay
    for (int i = 0; i < _controllers.length; i++) {
      Future.delayed(Duration(milliseconds: i * 100), () {
        if (mounted) {
          _controllers[i].repeat(reverse: true);
        }
      });
    }
  }

  @override
  void dispose() {
    for (final c in _controllers) {
      c.dispose();
    }
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      mainAxisAlignment: MainAxisAlignment.center,
      children: List.generate(3, (i) => AnimatedBuilder(
        animation: _animations[i],
        builder: (context, child) {
          return Container(
            margin: const EdgeInsets.symmetric(horizontal: 2),
            width: 3,
            height: 12 * _animations[i].value,
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(1.5),
            ),
          );
        },
      )),
    );
  }
}
